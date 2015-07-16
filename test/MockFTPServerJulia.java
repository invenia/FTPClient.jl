import org.mockftpserver.core.command.StaticReplyCommandHandler;
import org.mockftpserver.fake.filesystem.FileEntry;
import org.mockftpserver.fake.filesystem.FileSystem;
import org.mockftpserver.fake.filesystem.UnixFakeFileSystem;
import org.mockftpserver.fake.FakeFtpServer;
import org.mockftpserver.fake.UserAccount;
// import org.mockftpserver.stub.example.RemoteFile;

public class MockFTPServerJulia
{

//    private RemoteFile remoteFile;
    private static FakeFtpServer fakeFtpServer = new FakeFtpServer();

    public static boolean setUp()
    {
        System.out.println("Starting server");
        fakeFtpServer.start();
        System.out.println("Server started");

        int port = fakeFtpServer.getServerControlPort();

//        remoteFile = new RemoteFile();
//        remoteFile.setServer("localhost");
//        remoteFile.setPort(port);

        return true;
    }

    public static boolean setCommandResponse(String request, int code, String response)
    {
        StaticReplyCommandHandler featCommandHandler = new StaticReplyCommandHandler(code, response);
        fakeFtpServer.setCommandHandler(request, featCommandHandler);

        return true;
    }

    public static boolean setFile(String fileName, String content)
    {
        FileSystem fileSystem = new UnixFakeFileSystem();
        fileSystem.add(new FileEntry(fileName, content));
        fakeFtpServer.setFileSystem(fileSystem);

        return true;
    }

    public static boolean setUser(String userName, String passowrd, String homeDir)
    {
        UserAccount userAccount = new UserAccount(userName, passowrd, homeDir);
        fakeFtpServer.addUserAccount(userAccount);

        return true;
    }

//    public static boolean didFileUpload(String fileName, String expected)
//    {
//        String actuals = remoteFile.readFile(fileName);
//
//        return expected.equals(actuals);
//    }

    public static boolean tearDown()
    {
        System.out.println("Stoping server");
        fakeFtpServer.stop();
        System.out.println("Server started");

        return true;
    }
}