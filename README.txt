###########################################
### JamelsterApp - Google Drive Manager ###
###########################################

JamelsterApp - is a lightweight PowerShell GUI application that allows you to manage your Google Drive files with ease. Upload, download, list, and delete files—all without opening your browser.

------------------------------------------------------------------

> Features

- Authenticate with Google 
  Secure OAuth2 login using a one-time authorization code.

- Upload Files  
  Select and upload local files directly to your Google Drive.

- Download Files  
  Download any file from your Google Drive to your computer.

- List Files  
  View all files in your Drive including:
  	- File Name
  	- Type
  	- Last Modified Date

- Delete Files  
  Remove files from your Google Drive with confirmation.

-------------------------------------------------------------------

> Requirements

- Internet connection
- Windows with PowerShell
- Google Cloud Project with Drive API enabled
- OAuth 2.0 Client ID (Desktop App type)

-------------------------------------------------------------------

> Setup

1. > Enable Google Drive API  
   Go to [Google Cloud Console](https://console.cloud.google.com/) and enable the Drive API for your project.

2. > Create OAuth2 Credentials  
   - Application Type: Desktop Application  
   - Copy your #Client ID# and #Client Secret#

3. > Edit Script  
   Open `JamelsterApp.ps1` and paste your credentials:

   >powershell
   $client_id = "INSERT_CLIENT_ID Here"
   $client_secret = "INSERT_CLIENT_SECRET"
