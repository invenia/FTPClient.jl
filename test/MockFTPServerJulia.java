import org.mockftpserver.core.command.StaticReplyCommandHandler;
import org.mockftpserver.core.command.CommandNames;
import org.mockftpserver.fake.filesystem.FileEntry;
import org.mockftpserver.fake.filesystem.FileSystem;
import org.mockftpserver.fake.filesystem.UnixFakeFileSystem;
import org.mockftpserver.fake.FakeFtpServer;
import org.mockftpserver.fake.UserAccount;
import org.mockftpserver.stub.command.ListCommandHandler;
import org.mockftpserver.stub.command.RetrCommandHandler;
import org.mockftpserver.stub.command.StorCommandHandler;

public class MockFTPServerJulia
{

    private static FakeFtpServer fakeFtpServer = new FakeFtpServer();

    public static int setUp()
    {
        // Pick a free port.
        fakeFtpServer.setServerControlPort(0);

        System.out.println("Starting server");
        fakeFtpServer.start();
        System.out.println("Server started");

        int port = fakeFtpServer.getServerControlPort();

        return port;
    }

    public static boolean setCommandResponse(String request, int code, String response)
    {
        StaticReplyCommandHandler featCommandHandler = new StaticReplyCommandHandler(code, response);
        fakeFtpServer.setCommandHandler(request, featCommandHandler);

        return true;
    }

    public static boolean setErrors()
    {
        ListCommandHandler listCommandHandler = new ListCommandHandler();
        RetrCommandHandler retrCommandHandler = new RetrCommandHandler();
        StorCommandHandler storCommandHandler = new StorCommandHandler();
        listCommandHandler.setFinalReplyCode(550);
        retrCommandHandler.setFinalReplyCode(550);
        storCommandHandler.setFinalReplyCode(550);
        fakeFtpServer.setCommandHandler(CommandNames.RETR, retrCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.LIST, listCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.STOR, storCommandHandler);

        return true;
    }

    public static boolean setFile(String fileName, String content)
    {

        if(fakeFtpServer.getFileSystem() == null)
        {
            FileSystem fileSystem = new UnixFakeFileSystem();
            fakeFtpServer.setFileSystem(fileSystem);
        }

        FileEntry file = new FileEntry(fileName, content);
        fakeFtpServer.getFileSystem().add(file);

        return true;
    }

    public static boolean setUser(String userName, String password, String homeDir)
    {
        UserAccount userAccount = new UserAccount(userName, password, homeDir);
        fakeFtpServer.addUserAccount(userAccount);

        return true;
    }

    public static boolean tearDown()
    {
        System.out.println("Stoping server");
        fakeFtpServer.stop();
        System.out.println("Server stopped");

        return true;
    }
}
