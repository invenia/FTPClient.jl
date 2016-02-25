import org.mockftpserver.core.command.StaticReplyCommandHandler;
import org.mockftpserver.core.command.CommandNames;
import org.mockftpserver.fake.filesystem.FileEntry;
import org.mockftpserver.fake.filesystem.DirectoryEntry;
import org.mockftpserver.fake.filesystem.FileSystem;
import org.mockftpserver.fake.filesystem.UnixFakeFileSystem;
import org.mockftpserver.fake.FakeFtpServer;
import org.mockftpserver.fake.UserAccount;
import org.mockftpserver.stub.command.NlstCommandHandler;
import org.mockftpserver.stub.command.RetrCommandHandler;
import org.mockftpserver.stub.command.StorCommandHandler;
import org.mockftpserver.stub.command.ListCommandHandler;
import org.mockftpserver.stub.command.PwdCommandHandler;
import org.mockftpserver.stub.command.TypeCommandHandler;

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

    public static boolean undoErrors()
    {
        NlstCommandHandler nlstCommandHandler = new NlstCommandHandler();
        RetrCommandHandler retrCommandHandler = new RetrCommandHandler();
        StorCommandHandler storCommandHandler = new StorCommandHandler();
        PwdCommandHandler pwdCommandHandler = new PwdCommandHandler();
        ListCommandHandler listCommandHandler = new ListCommandHandler();
        TypeCommandHandler typeCommandHandler = new TypeCommandHandler();
        fakeFtpServer.setCommandHandler(CommandNames.NLST, nlstCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.RETR, retrCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.STOR, storCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.PWD, pwdCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.LIST, listCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.TYPE, typeCommandHandler);

        return true;
    }

    public static boolean setErrors()
    {
        NlstCommandHandler nlstCommandHandler = new NlstCommandHandler();
        RetrCommandHandler retrCommandHandler = new RetrCommandHandler();
        StorCommandHandler storCommandHandler = new StorCommandHandler();
        PwdCommandHandler pwdCommandHandler = new PwdCommandHandler();
        nlstCommandHandler.setFinalReplyCode(550);
        retrCommandHandler.setFinalReplyCode(550);
        storCommandHandler.setFinalReplyCode(550);
        pwdCommandHandler.setReplyCode(451);
        fakeFtpServer.setCommandHandler(CommandNames.NLST, nlstCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.RETR, retrCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.STOR, storCommandHandler);
        fakeFtpServer.setCommandHandler(CommandNames.PWD, pwdCommandHandler);

        return true;
    }

    public static boolean setListError()
    {
        ListCommandHandler listCommandHandler = new ListCommandHandler();
        listCommandHandler.setFinalReplyCode(550);
        fakeFtpServer.setCommandHandler(CommandNames.LIST, listCommandHandler);

        return true;
    }

    public static boolean setTypeError()
    {
        TypeCommandHandler typeCommandHandler = new TypeCommandHandler();
        typeCommandHandler.setReplyCode(451);
        fakeFtpServer.setCommandHandler(CommandNames.TYPE, typeCommandHandler);

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

    public static boolean setDirectory(String directoryName)
    {

        if(fakeFtpServer.getFileSystem() == null)
        {
            FileSystem fileSystem = new UnixFakeFileSystem();
            fakeFtpServer.setFileSystem(fileSystem);
        }

        DirectoryEntry directory = new DirectoryEntry(directoryName);
        fakeFtpServer.getFileSystem().add(directory);

        return true;
    }

    public static boolean setByteFile(String fileName, String hex)
    {

        if(fakeFtpServer.getFileSystem() == null)
        {
            FileSystem fileSystem = new UnixFakeFileSystem();
            fakeFtpServer.setFileSystem(fileSystem);
        }

        FileEntry file = new FileEntry(fileName);
        file.setContents(hexStringToByteArray(hex));
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

    public static boolean remove(String path)
    {
        return fakeFtpServer.getFileSystem().delete(path);
    }

    public static boolean fileExists(String path)
    {
        return fakeFtpServer.getFileSystem().isFile(path);
    }

    public static boolean directoryExists(String path)
    {
        return fakeFtpServer.getFileSystem().isDirectory(path);
    }

    public static String getFileContents(String path)
    {
        return convertStreamToString(((FileEntry)fakeFtpServer.getFileSystem().getEntry(path)).createInputStream());
    }

    private static byte[] hexStringToByteArray(String s)
    {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2)
        {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                 + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }

    // http://stackoverflow.com/questions/309424/read-convert-an-inputstream-to-a-string/5445161#5445161
    private static String convertStreamToString(java.io.InputStream is)
    {
        java.util.Scanner s = new java.util.Scanner(is).useDelimiter("\\A");
        return s.hasNext() ? s.next() : "";
    }
}
