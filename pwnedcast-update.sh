#!/bin/busybox

# Start infinite loop to imitate the google updater
while true
do
	echo "PWNEDCAST-OTA: Running PwnedCast OTA Updater!"

	# Are we allowed to run?
	if [ -f /chrome/disable_ota ]
	then
		echo "PWNEDCAST-OTA: OTA updates disabled per user request, Terminating"
		
		# Create a empty loop so this script is never ran again.
		while true
		do
			sleep 72000
		done
		
		# Delete run file
		rm /tmp/.pwnedcastOTA
		
		# Somehow, if we break out, exit, do NOT continue
		exit 0
	fi
	
	# Are we already running?
	if [ -f /tmp/.pwnedcastOTA ]
	then
		echo "PWNEDCAST-OTA: Already Running, Terminating"
		exit 1
	fi
	
	# We are running, so the world must know
	touch /tmp/.pwnedcastOTA

	# Delete any existing OTA
	if [ -f /cache/eureka_image.zip ]
	then
		rm /cache/eureka_image.zip
	fi

	# Variables used for the update check
	BuildVersion="$(getprop ro.build.version.incremental)"
	BuildRevision="$(cat /chrome/pwnedcast_ver)"
	SerialHash=`busybox sha1sum /factory/serial.txt | busybox awk '{ print $1 }'` # We only use your serial hash
	URL="http://ota.team-eureka.com/ota/update.php?version=$BuildVersion-$BuildRevision&serial=$SerialHash"

	# Check for the update
	echo "PWNEDCAST-OTA: Checking for Updates"
	Response="$(busybox wget -q $URL -O - )"

	# Error checking for update, due to server/web issues
	if [ $? -ne 0 ]
	then
		echo "PWNEDCAST-OTA: Error Checking for update, Connection Issues"
		echo "PWNEDCAST-OTA: Restarting Service in 5 Minutes"
	
		# Delete run file
		rm /tmp/.pwnedcastOTA
	
		sleep 300
		exit 1
	
	# Update is available, do something
	elif [ "$Response" != "NoUpdate" ]
	then
		echo "PWNEDCAST-OTA: Update Found! Downloading now!"
		busybox wget -q "$Response" -O /cache/eureka_image.zip
		if [ $? -ne 0 ];
		then
			echo "PWNEDCAST-OTA: Error Downloading, Terminating!"
			
			# Delete the failed update if it exists
			if [ -f /cache/eureka_image.zip ]
			then
				rm /cache/eureka_image.zip
			fi
			
			# Delete run file
			rm /tmp/.pwnedcastOTA
			
			exit 1
		else
			#Download was good, now download MD5 and check
			echo "PWNEDCAST-OTA: Update Downloaded Successfully"
			echo "PWNEDCAST-OTA: Downloading and Verifiying MD5 Hash"
			
			MD5Hash="$Response.md5"
			busybox wget -q "$MD5Hash" -O /cache/eureka_image.zip.md5
			
			# Did MD5 Download Successfully?
			if [ $? -ne 0 ];
			then
				# Delete run file
				rm /tmp/.pwnedcastOTA
				
				echo "PWNEDCAST-OTA: Error Downloading MD5, Terminating!"
				exit 1
			else
			
				# Check of MD5 is OK
				MD1=`busybox md5sum -c /cache/eureka_image.zip.md5 | busybox awk '{ print $2 }'`

				# Compare MD5's
				if [ "$MD1" != "OK" ]
				then
					# Bad MD5 Match
					echo "PWNEDCAST-OTA: Failed to verify, Deleting files and terminating."
					
					# Delete the failed update if it exists
					rm /cache/eureka_image.zip /cache/eureka_image.zip.md5
					
					# Delete run file
					rm /tmp/.pwnedcastOTA
					exit 1
				else
					# All went good
					echo "PWNEDCAST-OTA: File Verified Successfully!"
					
					# Delete md5 file as no need to keep it
					rm /cache/eureka_image.zip.md5
					
					# Delete run file
					rm /tmp/.pwnedcastOTA
					
					# we do this as a file needs to exist for content_shel ota update to work
					touch /cache/ota.zip
					
					echo "PWNEDCAST-OTA: Rebooting into Flashcast To Update..."
					curl -H "Content-Type: application/json" http://localhost:8008/setup/reboot -d '{"params":"ota"}' -X POST
				fi
			fi
		fi
	else
		echo "PWNEDCAST-OTA: No Update Required!"
	fi
	
	# Sleep a while
	echo "PWNEDCAST-OTA: Sleeping 20 hours"
	sleep 72000
	
	# Delete run file
	rm /tmp/.pwnedcastOTA

done
