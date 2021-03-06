#!/bin/bash

## First run script following DEP enrolment
## Neil Martin, University of East London
## Edited for MSU by Gabriel Marcelino - 4/23/2019

####################################################################################################
# Functions
####################################################################################################

####################################################################################################
# Encryption Functions
####################################################################################################

function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

####################################################################################################
# Secure Function!
#####################################################################################################

secure(){
# If user selects "secure"
if [ "$tosecure" == "Secure" ]; then
   echo "User clicked secure"
   /usr/local/MSU/BigHonkingText -R -s red "Setting up Secure Image Please wait"
   /usr/bin/touch /var/db/.SecureImage



# If user selects "Unsecure"
elif [ "$tosecure" == "Not Secure" ]; then
   echo "User clicked Not Secure or timeout was reached; now exiting."

fi

}

####################################################################################################
# App installation and setup!
#####################################################################################################
Appinstall(){
/usr/local/MSU/BigHonkingText -R -s red "Please wait while Apps are installed"
POLICY_ARRAY=(
    "Installing Adobe Acrobat DC,AcrobatDC"
    "Installing Jamf Suite,CasperClients"
    "Installing Firefox,Firefox"
    "Installing Google Chrome,GoogleChrome"
    "Installing Printer Drivers,HPDrivers"
    "Installing Printer Drivers,PrintLdap"
    "Installing Printer Drivers,SharpDrivers"
    "Installing Adobe Flash Player,AdobeFlash"
    "Installing MS Office 2019,MSOfficeUpdates"
    "Installing Java,Java8"
    "Installing Sophos AV,Sophos"
    "Installing VLC Player,VLC"
    )

    #Installing Adobe Lab Linceses
    STUAdobe=(
                "Acrobat%20CC%20STU%202019.190_Install.pkg.zip"
                "After%20Effects%20CC%20STU%202019.16.0.1_Install.pkg.zip"
                "Animate%20CC%20STU%202019.19.1_Install.pkg.zip"
                "Audition%20CC%20STU%202019.12.0.1_Install.pkg.zip"
                "Bridge%20CC%20STU%202019.9.0.2_Install.pkg.zip"
                "Character%20Animator%20CC%20STU%202019.2.0.1_Install.pkg.zip"
                "Dreamweaver%20CC%20STU%202019.19.0.1_Install.pkg.zip"
                "Illustrator%20CC%20STU%202019.23.0.1_Install.pkg.zip"
                "InCopy%20CC%20STU%202019.14.0_Install.pkg.zip"
                "InDesign%20CC%20STU%202019.14.0.1_Install.pkg.zip"
                "Lightroom%20Classic%20CC%20STU%202019.8.1_Install.pkg.zip"
                "Media%20Encoder%20CC%20STU%202019.13.0.2_Install.pkg.zip"
                "Photoshop%20CC%20STU%202019.20.0.2_Install.pkg.zip"
                "Prelude%20CC%20STU%202019.8.0.1_Install.pkg.zip"
                "Premiere%20Pro%20CC%20STU%202019.13.0.2_Install.pkg.zip"
                "Premiere%20Rush%20CC%20STU%202019.1.0.3_Install.pkg.zip"
                "XD%20CC%20STU%202019.16.0.2_Install.pkg.zip"
)
    # Checking policy array and adding the count from the additional options above.
    ARRAY_LENGTH="$((${#POLICY_ARRAY[@]}+ADDITIONAL_OPTIONS_COUNTER+${#STUAdobe[@]}))"
    echo "Command: Determinate: $ARRAY_LENGTH" >> "$DEP_NOTIFY_LOG"

    # Loop to run policies
  for POLICY in "${POLICY_ARRAY[@]}"; do
    echo "Status: $(echo "$POLICY" | cut -d ',' -f1)" >> "$DEP_NOTIFY_LOG"
      "$JAMF_BINARY" policy -event "$(echo "$POLICY" | cut -d ',' -f2)"
  done
  for Adobe in "${STUAdobe[@]}"; do
    echo "Status: $(echo "${Adobe//%20}")"  >> "$DEP_NOTIFY_LOG"
    "$JAMF_BINARY" install -package "$Adobe" -path https://jamfdis.montclair.edu/jamfshare/Packages/$Adobe -showProgress
  done

/usr/local/MSU/BigHonkingText -R -s red "Base Apps Complete"
}

# Set basic variables
osversion=$(/usr/bin/sw_vers -productVersion)
serial=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'"' '/IOPlatformSerialNumber/{print $4}')
JSSURL="https://jamf.montclair.edu:8443"
apiusername=$(DecryptString "$5" '9216dbf3bde77703' '349b7d30fc94df994f268186')
apipassword=$(DecryptString "$6" '7e07b4d36e97b71d' 'd10ac6497a109b1aae364525')
pashua="/private/var/MSUTools/Pashua.app/Contents/MacOS/Pashua"
cocoadialog="/private/var/MSUTools/cocoaDialog.app/Contents/MacOS/cocoaDialog"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
ADDITIONAL_OPTIONS_COUNTER=1
DEP_NOTIFY_LOG="/var/tmp/depnotify.log"
JAMF_BINARY="/usr/local/bin/jamf"
DEP_NOTIFY_REGISTER_DONE="/var/tmp/com.depnotify.registration.done"

# Function to add date to log entries
log(){
NOW="$(date +"*%Y-%m-%d %H:%M:%S")"
/bin/echo "$NOW": "$1"
}

# Logging for troubleshooting - view the log at /private/tmp/firstrun.log
/usr/bin/touch /private/tmp/firstrun.log
exec 2>&1>/private/tmp/firstrun.log

# Let's not go to sleep 
log "Disabling sleep..."
/usr/bin/caffeinate -d -i -m -s -u &
caffeinatepid=$!

# Disable Automatic Software Updates during provisioning
log "Disabling automatic software updates..."
/usr/sbin/softwareupdate --schedule off

# Set Network Time
log "Configuring Network Time Server..."
/usr/sbin/systemsetup -settimezone "America/New_York"
/usr/sbin/systemsetup -setusingnetworktime on

# Copy our wallpaper over Mojave's default
/bin/cp "/Library/Desktop Pictures/MSU.jpg" "/Library/Desktop Pictures/Mojave.heic"

# Check for existing Hostname extension attribute in JSS - if it's not there, we'll set up NoMAD Login with User Input mech, otherwise, we will proceed with Notify mech only!
log "Checking for existing Hostname and Role in JSS..."
eaxml=$(/usr/bin/curl "$JSSURL"/JSSResource/computers/serialnumber/"$serial"/subset/extension_attributes -u "$apiusername":"$apipassword" -H "Accept: text/xml")
computerName=$(/bin/echo "$eaxml" | /usr/bin/xpath '//extension_attribute[name="Hostname"' | /usr/bin/awk -F'<value>|</value>' '{print $2}')
computerRole=$(/bin/echo "$eaxml" | /usr/bin/xpath '//extension_attribute[name="Computer Role"' | /usr/bin/awk -F'<value>|</value>' '{print $2}')

# Wait for the setup assistant to complete before continuing
log "Waiting for Setup Assistant to complete..."
loggedInUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}     ')
while [[ "$loggedInUser" == "_mbsetupuser" ]]; do
	/bin/sleep 5
	loggedInUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}     ')
done

# Let's continue
log "Setup Assistant complete, continuing..."

if [[ "$computerName" == "" ]] || [[ "$computerRole" == "" ]]; then
	log "Hostname or Role not set in JSS, configuring NoMAD Login with User Input and Notify mech..."

	# Configure login window mech for User Input and Notify
    /usr/local/bin/authchanger -reset -preLogin NoMADLoginAD:UserInput NoMADLoginAD:Notify
	
	# Kill the Login Window process if it's running so NoMAD Login can take over
	if pgrep loginwindow; then 
 	   /usr/bin/killall -HUP loginwindow
	fi

	# Wait for the user data to be submitted...
	while [[ ! -f /var/tmp/userinputoutput.txt ]]; do
		log "Waiting for user data..."
		/bin/sleep 5
	done

	log "User data submitted, continuing setup..."

	# Let's read the user data into some variables...
	computerName=$(/usr/libexec/plistbuddy /var/tmp/userinputoutput.txt -c "print 'Hostname'")
	computerRole=$(/usr/libexec/plistbuddy /var/tmp/userinputoutput.txt -c "print 'Computer Role'")

	# Update Hostname and Computer Role in JSS
	# Create xml
	/bin/cat << EOF > /var/tmp/name.xml
<computer>
    <extension_attributes>
        <extension_attribute>
            <name>Hostname</name>
            <value>$computerName</value>
        </extension_attribute>
    </extension_attributes>
</computer>
EOF
	## Upload the xml file
	/usr/bin/curl -sfku "$apiusername":"$apipassword" "$JSSURL"/JSSResource/computers/serialnumber/"$serial" -H "Content-type: text/xml" -T /var/tmp/name.xml -X PUT
	# Create xml
	/bin/cat << EOF > /var/tmp/role.xml
<computer>
    <extension_attributes>
        <extension_attribute>
            <name>Mac User Role</name>
            <value>$computerRole</value>
        </extension_attribute>
    </extension_attributes>
</computer>
EOF
	## Upload the xml file
	/usr/bin/curl -sfku "$apiusername":"$apipassword" "$JSSURL"/JSSResource/computers/serialnumber/"$serial" -H "Content-type: text/xml" -T /var/tmp/role.xml -X PUT
fi

# Carry on with the setup...

	# Configure login window mech for User Input and Notify
    /usr/local/bin/authchanger -reset -preLogin NoMADLoginAD:UserInput NoMADLoginAD:Notify
/bin/echo "Command: MainTitle: Setting things up HERE WE GO..."  >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Please wait while we set this Mac up with the software and settings it needs. This may take a few hours. We'll restart automatically when we're finished. \n \n Role: "$computerRole" Mac \n Computer Name: "$LHN" \n macOS Version: "$osversion""  >> /var/tmp/depnotify.log

log "Initiating Configuration..."

# Time to set the hostname...
/bin/echo "Status: Setting computer name" >> /var/tmp/depnotify.log
log "Setting hostname to "$computerName"..."
/usr/local/bin/jamf setComputerName -name "$computerName"

# Bind to AD
log "Binding to Active Directory..."
/bin/echo "Status: Binding to Active Directory..." >> /var/tmp/depnotify.log
/usr/local/bin/jamf policy -event BindAD

# Deploy policies for all Macs
log "Running software deployment policies..."
/bin/echo "Status: Installing software, please wait..." >> /var/tmp/depnotify.log

Appinstall

if [ "$computerRole" == "CA134" ]; then
   echo "Computer Role is Calcia 134"
   "$JAMF_BINARY" policy -event SPSS

# If user selects "Unsecure"
else
    echo "No Computer role"
fi
# Run a recon, set asset tag and room number
#/bin/echo "Status: Updating inventory..." >> /var/tmp/depnotify.log
#log "Setting variables for asset tag and room..."
#assetno=$(/bin/echo "$computerName" | /usr/bin/cut -d '-' -f 2)
#room=$(/bin/echo "$computerName" | /usr/bin/cut -d '-' -f 1)
#log "Running recon..."
#/usr/local/bin/jamf recon -assetTag "$assetno" -room "$room"

# Run a Software Update
log "Running Apple Software Update..."
#/usr/local/bin/jamf policy -event DeploySUS

# Finishing up

/bin/echo "Command: MainTitle: All done!"  >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: This Mac will restart shortly and you'll be able to log in. \n \n If you need any assistance, please contact the UEL IT Service Desk. \n \n Telephone: 020 8223 2468 \n Email: servicedesk@uel.ac.uk"  >> /var/tmp/depnotify.log
/bin/echo "Status: Restarting, please wait..." >> /var/tmp/depnotify.log

# Reset login window authentication mech to Apple
log "Resetting Login Window..."
/usr/local/bin/authchanger -reset

##Checking for Latest update

/usr/sbin/softwareupdate -i -a

# Kill caffeinate and restart with a 2 minute delay
log "Decaffeinating..."
log "Restarting..."
kill "$caffeinatepid"
sudo reboot &

log "Done!"