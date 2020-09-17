package com.injectionforxcode;

import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.PlatformDataKeys;
import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.ui.Messages;
import com.intellij.util.ui.UIUtil;

import java.net.*;
import java.io.*;

/**
 * Copyright (c) 2013 John Holdsworth. All rights reserved.
 *
 * $Id: //depot/ResidentEval/AppCodePlugin/src/com/injectionforxcode/InjectionAction.java#3 $
 *
 * Created with IntelliJ IDEA.
 * Date: 24/02/2013
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * If you want to "support the cause", consider a paypal donation to:
 *
 * Revised 2020 for use with InjectionIII. Seems to only build with
 * old versions of IntelliJ community edition e.g. IntelliJ IDEA 15 CE
 *
 * injectionforxcode@johnholdsworth.com
 *
 */

public class InjectionAction extends AnAction {

    static String bundlePath = "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle";
    static short INJECTION_PORT = 8898;
    static String CHARSET = "UTF-8";

    enum InjectionCommand {
        Connected, Watching, Log, Signed, Load, Inject, ProcPath, Xprobe, Eval, VaccineSettingChanged, Trace, Untrace
    }
    enum InjectionResponse {
        Complete, Pause, Sign, Error
    }

    static InjectionAction plugin;

    {
        startServer(INJECTION_PORT);
        plugin = this;
    }

    public void actionPerformed(AnActionEvent event) {
        injectFile(event);
    }

    static int alert(final String msg) {
        UIUtil.invokeAndWaitIfNeeded(new Runnable() {
            public void run() {
                Messages.showMessageDialog(msg, "Injection Plugin", Messages.getInformationIcon());
            }
        });
        return 0;
    }

    static void error(String where, Throwable e) {
        alert(where + ": " + e + " " + e.getMessage());
        throw new RuntimeException("Injection Plugin error", e);
    }

    void startServer(int portNumber) {
        try {
            final ServerSocket serverSocket = new ServerSocket();
            serverSocket.setReuseAddress(true);
            serverSocket.bind(new InetSocketAddress(portNumber),5);

            new Thread(new Runnable() {
                public void run() {
                    while (true) {
                        try {
                            serviceClientApp(serverSocket.accept());
                        } catch (Throwable e) {
                            error("Error on accept", e);
                        }
                    }
                }
            }).start();
        }
        catch (IOException e) {
            error("Unable to bind Server Socket", e);
        }
    }

    String frameworks = "", executablePath = "", arch = "";
    volatile OutputStream clientOutput;
    boolean sentProjectPath = false;

    void serviceClientApp(final Socket socket) throws Throwable {
        socket.setTcpNoDelay(true);

        final InputStream clientInput = socket.getInputStream();
        clientOutput = socket.getOutputStream();
        sentProjectPath = false;

        // Temporary dorectory to use
        final String tmpDir = "/tmp", prefix = tmpDir+"/eval";
        writeString(clientOutput, tmpDir);

        // Sanity check
        if (!"bvijkijyhbtrbrebzjbbzcfbbvvq".equals(readString(clientInput)))
            return;

        // Not relevant for this version
        // Bundle does all the work.
        frameworks = readString(clientInput);
        arch = readString(clientInput);
        executablePath = readString(clientInput);

        new Thread(new Runnable() {
            public void run() {
                try {
                    while (true) {
                        int resp = readInt(clientInput) & 0x7fffffff;
                        if (resp < InjectionResponse.values().length)
                            switch (InjectionResponse.values()[resp]) {
                                case Sign:
                                    String dylib = readString(clientInput);
                                    if (!new File(dylib).exists())
                                        dylib = prefix+dylib;
                                    else if (!dylib.startsWith(prefix))
                                        error("Signing exception", new IOException("Invalid path"));
                                    try {
                                        Process process = Runtime.getRuntime().exec(new String[] {"/bin/bash", "-c",
                                                "(export CODESIGN_ALLOCATE=/Applications/Xcode.app" +
                                                        "/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate; " +
                                                        "/usr/bin/codesign --force -s \"-\" \""+dylib+"\")"});
                                        int status = process.waitFor();
                                        writeCommand(clientOutput, InjectionCommand.Signed.ordinal(), status == 0 ? "1" : "0");
                                    }
                                    catch (Exception e) {
                                        error("Signing exception", e);
                                    }
                                    break;
                                case Error:
                                    alert("Injection error: "+readString(clientInput));
                                default:
                                    break;
                            };
                    }
                }
                catch (Exception e) {
                }
                finally {
                    try {
                        socket.close();
                    }
                    catch (IOException e) {
                    }
                    clientOutput = null;
                }
            }
        }).start();
    }

    int injectFile(AnActionEvent event) {

        try {
            if (!new File(bundlePath).exists())
                return alert("Please download InjectionIII from the Mac App Store.");
            if (clientOutput == null)
                return alert("Application not running/connected.");

            Project project = event.getData(PlatformDataKeys.PROJECT);
            if (project == null)
                alert("Null project");
            if (!sentProjectPath) {
                VirtualFile proj = project.getBaseDir();
                String projectPath = proj.getPath() + "/" + proj.getName() + ".xcworkspace";
                if (!new File(projectPath).exists())
                    projectPath = proj.getPath() + "/" + proj.getName() + ".xcodeproj";
                writeCommand(clientOutput, InjectionCommand.Connected.ordinal(), projectPath);
                sentProjectPath = true;
            }

            VirtualFile vf = event.getData(PlatformDataKeys.VIRTUAL_FILE);
            if (vf == null)
                return 0;

            String selectedFile = vf.getCanonicalPath();
            FileDocumentManager.getInstance().saveAllDocuments();
            writeCommand(clientOutput, InjectionCommand.Inject.ordinal(), selectedFile);
        }
        catch (Throwable e) {
            error("Inject File error", e);
        }

        return 0;
    }

    // Socket I/O
    static int unsign(byte  b) {
        return (int)b & 0xff;
    }

    static int readInt(InputStream s) throws IOException {
        byte bytes[] = new byte[4];
        if (s.read(bytes) != bytes.length)
            throw new IOException("readInt() EOF");
        return unsign(bytes[0]) + (unsign(bytes[1])<<8) + (unsign(bytes[2])<<16) + (unsign(bytes[3])<<24);
    }

    static String readString(InputStream s) throws IOException {
        int pathLength = readInt(s);
        if (pathLength > 1000000)
            pathLength = readInt(s);
        byte buffer[] = new byte[pathLength];
        if (s.read(buffer) != pathLength)
            alert("Bad path read, pathLength :"+pathLength);
        return new String(buffer, 0, pathLength, CHARSET);
    }

    static void writeInt(OutputStream s, int i1) throws IOException {
        byte bytes[] = new byte[4];
        bytes[0] = (byte) (i1);
        bytes[1] = (byte) (i1 >> 8);
        bytes[2] = (byte) (i1 >> 16);
        bytes[3] = (byte) (i1 >> 24);
        s.write(bytes);
        s.flush();
    }

    static void writeString(OutputStream s, String path) throws IOException {
        byte bytes[] = path.getBytes(CHARSET);
        writeInt(s, bytes.length);
        s.write(bytes);
        s.flush();
    }

    static void writeCommand(OutputStream s, int command, String string) throws IOException {
        writeInt(s, command);
        if (string != null)
            writeString(s, string);
    }
}
