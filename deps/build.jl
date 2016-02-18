# Removing "*.jar" because it did not build on AppVeyor
run(`unzip -oj -d ext "MockFtpServer-2.6-bin.zip"`)
run(`unzip -oj -d ext "slf4j-1.7.12.zip" "*/slf4j-api-1.7.12.jar"`)

run(`javac -Djava.ext.dirs=ext ../test/MockFTPServerJulia.java`)
