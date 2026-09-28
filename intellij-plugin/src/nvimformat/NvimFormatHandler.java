package nvimformat;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ModalityState;
import com.intellij.openapi.command.WriteCommandAction;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.fileEditor.impl.NonProjectFileWritingAccessProvider;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectLocator;
import com.intellij.openapi.util.Computable;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import com.intellij.psi.codeStyle.CodeStyleManager;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.FullHttpRequest;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpResponseStatus;
import io.netty.handler.codec.http.QueryStringDecoder;
import org.jetbrains.ide.HttpRequestHandler;
import org.jetbrains.io.Responses;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;

/**
 * POST /api/nvim-format (body: path=<dosya>) — dosyayı açık IDE'de, ait olduğu projenin kod stiliyle
 * (IDE'deki Ctrl+Alt+L ile aynı) yerinde formatlar. Dosyanın projesi IDE'de açık değilse 404 döner;
 * nvim tarafı o zaman `idea format` komut satırına düşer.
 */
public final class NvimFormatHandler extends HttpRequestHandler {

    private static final String PREFIX = "/api/nvim-format";

    @Override
    public boolean isSupported(FullHttpRequest request) {
        return request.method() == HttpMethod.POST && request.uri().startsWith(PREFIX);
    }

    @Override
    public boolean process(QueryStringDecoder urlDecoder, FullHttpRequest request, ChannelHandlerContext context) {
        String body = request.content().toString(StandardCharsets.UTF_8);
        List<String> paths = new QueryStringDecoder(body, StandardCharsets.UTF_8, false).parameters().get("path");
        if (paths == null || paths.isEmpty()) {
            Responses.send(HttpResponseStatus.BAD_REQUEST, context.channel(), request, "path eksik");
            return true;
        }

        VirtualFile file = LocalFileSystem.getInstance().refreshAndFindFileByNioFile(Path.of(paths.get(0)));
        if (file == null || file.isDirectory()) {
            Responses.send(HttpResponseStatus.BAD_REQUEST, context.channel(), request, "dosya bulunamadı");
            return true;
        }
        Project project = ApplicationManager.getApplication()
                .runReadAction((Computable<Project>) () -> ProjectLocator.getInstance().guessProjectForFile(file));
        if (project == null || project.isDisposed()) {
            Responses.send(HttpResponseStatus.NOT_FOUND, context.channel(), request, "dosyanın projesi IDE'de açık değil");
            return true;
        }

        String error = reformat(project, file);
        if (error == null) {
            Responses.send(HttpResponseStatus.OK, context.channel(), request, "ok");
        } else {
            Responses.send(HttpResponseStatus.INTERNAL_SERVER_ERROR, context.channel(), request, error);
        }
        return true;
    }

    // IntelliJ komut satırı formatter'ının (FileSetFormatter) yaptığı adımlar, projenin kendi ayarlarıyla
    private static String reformat(Project project, VirtualFile file) {
        String[] error = new String[1];
        ApplicationManager.getApplication().invokeAndWait(() -> {
            try {
                Document document = FileDocumentManager.getInstance().getDocument(file);
                PsiFile psiFile = document == null ? null : PsiDocumentManager.getInstance(project).getPsiFile(document);
                if (psiFile == null) {
                    error[0] = "PSI oluşturulamadı";
                    return;
                }
                NonProjectFileWritingAccessProvider.allowWriting(List.of(file));
                WriteCommandAction.runWriteCommandAction(project, () -> {
                    CodeStyleManager.getInstance(project).reformatText(psiFile, 0, psiFile.getTextLength());
                    PsiDocumentManager.getInstance(project).commitDocument(document);
                });
                FileDocumentManager.getInstance().saveDocument(document);
            } catch (RuntimeException e) {
                error[0] = String.valueOf(e);
            }
        }, ModalityState.nonModal());
        return error[0];
    }
}
