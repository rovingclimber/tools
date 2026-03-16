# **Seamless YubiKey SSH on Windows 11**

This project provides a "Kleopatra-style" experience for using multiple YubiKeys with OpenSSH on Windows. It solves the common "Invalid Format" errors caused by the Windows OpenSSH client attempting to probe multiple FIDO2 identities at once.

## **❓ Why the complexity?**

You might wonder why we need a Task Scheduler and a GUI just to use an SSH key.

* **The Single-Key Scenario:** If you only own **one** YubiKey, you don't need any of this. You can simply put your one stub in your config and call it a day. However, relying on a single key is dangerous; if you lose it, you are locked out of your servers.  
* **The Multi-Key Problem:** Best practice is to have multiple keys (e.g., Primary, Backup, and a Travel/BIO key). On Linux and macOS, the SSH client gracefully skips missing keys. On Windows, the fido2.dll provider often crashes the connection attempt if it "probes" a key stub that isn't physically plugged in.  
* **The Solution:** We use a **PowerShell GUI script** that is automatically triggered by the system the moment you insert a YubiKey.  
  1. **Trigger:** Windows detects the hardware insertion via Event Logs.  
  2. **Prompt:** A tiny, dark-themed window appears, asking you to select which identity to use.  
  3. **Action:** The script instantly rewrites your SSH config file to point specifically to that key, ensuring your next ssh command works perfectly.

## **🛡️ Security: What is actually "Private"?**

Traditional SSH keys require you to guard your private key file with your life. This setup is different:

* **The Real Private Key:** Stays inside the YubiKey's secure element. It can **never** be exported or copied, even by you.  
* **The Key Stub (Non-Secret):** The file created in your .ssh folder (without the .pub extension) is just a "pointer" or "handle." It tells OpenSSH which YubiKey to look for. If someone steals this file, they **cannot** log into your servers without your physical YubiKey and your PIN.  
* **The Public Key (Non-Secret):** This is shared with the world (the server).

**Bottom Line:** You do not need to worry about encrypting or hiding your .ssh folder as long as your YubiKey has a strong PIN set.

## **🚀 Step 0: Enable the SSH Agent**

Before starting, ensure the Windows SSH Agent service is enabled. This allows Windows to "remember" your touch/PIN for the duration of your session.

Run this in **PowerShell (Admin)**:

Set-Service \-Name ssh-agent \-StartupType Automatic  
Start-Service \-Name ssh-agent

## **🚀 Step 1: Generate All Your Keys**

The most efficient workflow is to generate **all** your intended keys (Primary, Backup, etc.) first.

### **Creating your Keys**

If PowerShell is not displaying the PIN or Touch prompts correctly, use the **Command Prompt (cmd)**. **Note:** You do NOT need Administrator rights to create keys.

First, navigate to your .ssh folder:

if not exist %USERPROFILE%\\.ssh mkdir %USERPROFILE%\\.ssh && cd /d %USERPROFILE%\\.ssh

Then, run this command for each YubiKey you own. **Swap the hardware for each run:**

ssh-keygen \-t ed25519-sk \-O resident \-O application=ssh:key1

* **\-O resident**: Tells the YubiKey to store the key internally.  
* **\-O application=ssh:label**: Gives the key a "label" inside the hardware. Use a different name for each key (e.g., key1, key2).

### **The "Overwrite" Warning (It's a Lie)**

When creating or downloading keys, Windows might show a scary prompt saying:

*"A credential for this site already exists on this security key. Do you want to overwrite it?"*

**Ignore it.** This warning is a generic FIDO2 message. As long as your application labels are unique, your keys are perfectly safe. You are not deleting your keys; you are simply updating the local metadata stub.

## **🛡️ Step 2: Authorize All Keys on the Remote Server**

Once you have your collection of .pub files, add them to the server. You can add more later at any time.

1. **Collect your Public Keys:** Open each .pub file in Notepad and copy the contents.  
2. **Access the Server:** Log into your remote server using your existing credentials.  
3. **Add to authorized\_keys:** Run this on the server for **each** key:  
   echo "PASTE\_YOUR\_PUBKEY\_HERE" \>\> \~/.ssh/authorized\_keys

4. **Set Permissions:**  
   chmod 700 \~/.ssh  
   chmod 600 \~/.ssh/authorized\_keys

## **🛠️ Portability: Moving to a New Machine**

You don't need to back up your \~/.ssh folder. On a new machine, plug in your YubiKey and run this in **cmd**:

if not exist %USERPROFILE%\\.ssh mkdir %USERPROFILE%\\.ssh && cd /d %USERPROFILE%\\.ssh && ssh-keygen \-K

OpenSSH will pull the public keys and stubs directly from the hardware.

## **🤖 The "Switchboard" Automation**

### **⚠️ IMPORTANT: Config Overwrite Warning**

**The Switchboard GUI will OVERWRITE your \~/.ssh/config file without warning.** This is necessary to fix the Windows multi-key bug by ensuring only the active key is listed. If you have custom SSH aliases, back them up before using the automation.

### **Installation**

1. Place yubikey\_switchboard.ps1 in your \~/.ssh/ folder.  
2. Update the KeyMap inside the script with your specific filenames and serials.  
3. Run register\_yubikey\_task.ps1 as **Administrator** to enable the hardware trigger.

## **🛡️ Server-Side Setup**

Use the provided setup\_fido2\_ssh.sh on your Linux servers to ensure they are running OpenSSH 8.2+ and have the necessary libraries.

## **📂 Example Directory Structure**

C:\\Users\\Username\\.ssh\\  
├── config                        \# Managed by Switchboard  
├── id\_ed25519\_sk\_key1            \# Key Stub (Safe to share/lose)  
├── id\_ed25519\_sk\_key1.pub        \# Public Key  
├── id\_ed25519\_sk\_key2            \# Key Stub  
├── id\_ed25519\_sk\_key2.pub        \# Public Key  
├── known\_hosts                   \# Known server fingerprints  
├── yubikey\_switchboard.ps1       \# The GUI app  
└── register\_yubikey\_task.ps1     \# The automation installer  
