import org.mockftpserver.stub.StubFtpServer;
import org.mockftpserver.core.command.StaticReplyCommandHandler;

public class MockFTPServerJulia
{

    private static StubFtpServer stubFtpServer;

    public static int setUp()
    {
        System.out.println("Starting server");
        stubFtpServer = new StubFtpServer();
        final String FEAT_TEXT = "Login successful.";
        StaticReplyCommandHandler featCommandHandler = new StaticReplyCommandHandler(230, FEAT_TEXT);
        stubFtpServer.setCommandHandler("AUTH", featCommandHandler);
        stubFtpServer.start();
        System.out.println("Server started");

        return 1;
    }

    public static int tearDown()
    {
        System.out.println("Stoping server");
        stubFtpServer.stop();
        System.out.println("Server started");

        return 1;
    }
}