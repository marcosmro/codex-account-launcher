-- A local launcher. It never copies credentials or modifies the ChatGPT app.
on run
 try
  set userHome to POSIX path of (path to home folder)
  set profilesRoot to userHome & "Library/Application Support/ChatGPT Account Launcher/Profiles"
  set profileNames to {}
  set listCommand to "if [ -d " & quoted form of profilesRoot & " ]; then for p in " & quoted form of profilesRoot & "/*; do [ -d \"$p\" ] && basename \"$p\"; done; fi; true"
  set savedNames to do shell script listCommand
  if savedNames is not "" then set profileNames to paragraphs of savedNames
  set choices to {"Main account — existing ChatGPT", "Second account"} & profileNames & {"＋ Add an account…"}
  set picked to choose from list choices with title "ChatGPT Account Launcher" with prompt "Choose the ChatGPT / Codex account to open.\nNew accounts ask you to sign in once." default items {"Main account — existing ChatGPT"} OK button name "Open" cancel button name "Cancel"
  if picked is false then return
  set accountName to item 1 of picked
  set appPath to "/Applications/ChatGPT.app"
  try
   do shell script "test -d " & quoted form of appPath
  on error
   set appPath to POSIX path of (choose file with prompt "Locate the ChatGPT desktop app that includes Codex:" of type {"com.apple.application-bundle"})
  end try
  if accountName is "Main account — existing ChatGPT" then
   do shell script "/usr/bin/open " & quoted form of appPath
   return
  end if
  if accountName is "＋ Add an account…" then
   repeat
    set nameResult to display dialog "Name this account (for example Work or Personal).\nUse letters, numbers, spaces, hyphens or underscores." default answer "Work" with title "Add ChatGPT account" buttons {"Cancel", "Create & Open"} default button "Create & Open"
    set accountName to text returned of nameResult
    set isValid to true
    if (count accountName) < 1 or (count accountName) > 40 then set isValid to false
    repeat with c in characters of accountName
     if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_" does not contain (c as text) then set isValid to false
    end repeat
    if accountName begins with " " or accountName ends with " " then set isValid to false
    if accountName is "Second account" or accountName is "Main account" then set isValid to false
    if isValid then exit repeat
    display dialog "Choose a name of 1–40 characters without leading or trailing spaces. Main account and Second account are reserved." buttons {"OK"} default button "OK" with title "Choose another name"
   end repeat
  end if
  if accountName is "Second account" then
   -- Reuse the paths supplied earlier in the chat, if already used.
   set codexHome to userHome & ".codex-second"
   set appData to userHome & "Library/Application Support/ChatGPT-Second"
  else
   set accountRoot to profilesRoot & "/" & accountName
   set codexHome to accountRoot & "/Codex"
   set appData to accountRoot & "/AppData"
  end if
  do shell script "/bin/mkdir -p " & quoted form of codexHome & " " & quoted form of appData
  set launchCommand to "/usr/bin/open -n " & quoted form of appPath & " --env " & quoted form of ("CODEX_HOME=" & codexHome) & " --env " & quoted form of ("CODEX_ELECTRON_USER_DATA_PATH=" & appData) & " --args " & quoted form of ("--user-data-dir=" & appData)
  do shell script launchCommand
 on error errorText number errorNumber
  if errorNumber is not -128 then display dialog "Could not open the account.\n\n" & errorText with title "ChatGPT Account Launcher" buttons {"OK"} default button "OK" with icon caution
 end try
end run
