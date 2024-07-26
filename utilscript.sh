#!/bin/bash
#Shows the PID
echo "The PID of this shell is: $BASHPID"

#Function to log the login information (who/when)
logged_in() {
    #echo "user [$(whoami)] logged on at: $(last | awk '{if(NR==1) printf $7 " on " $4"-"$6"-"$5 }')" >> .utilLogFile
    logged_in_user=$(whoami)
        last_login=$(last -n 1 "$logged_in_user" | awk '{if(NR==1) printf $7 " on " $4"-"$6"-"$5 }')

        #puts the user and time of log on
        user_info="user [$logged_in_user] logged on at: $last_login"

        #checks if its already in log file, if not then adds it
        if ! grep -qF "$user_info" .utilLogFile; then
            echo "$user_info" >> .utilLogFile
        fi
}

#This is called before most things so that it is logged in the log file first. Only the pid is shown first.
logged_in

#Adds a little help menu
command_help(){
  echo "#################################################"
  echo "############### Help  ###########################"
  echo "#################################################"
  echo "This script can accept multiple functions, it can"
  echo "generate UUID3 and UUID4, run some stats on the "
  echo "_directory folder."
  echo ""
  echo "Syntax: utilscript [-a | b | c | i | n | o | l]"
  echo "options:"
  echo "a   Generate and print a UUID4"
  echo "b   Generate and print a UUID3"
  echo "c   Report file sizes and types of _Directory"
  echo "    and longest and shortest file lengths"
  echo "i   Allows you to navigate to the _directory folder"
  echo "n   Name for uuid V3 - allows you to not create collisions"
  echo "o   Allows for setting output file"
  echo "l   Lists the last UUIDs created"
  exit 0
}

#shows the last uuid from v3/v4 from the log file (including date and person creating)
uuid_check() {
  last_uuid_v3=$(grep "UUID_V3" ".utilLogFile" | tail -1 | awk '{for(i=1; i<=NF-5; i++) printf $i " "; print ""}')
  last_uuid_v4=$(grep "UUID_V4" ".utilLogFile" | tail -1 | awk '{for(i=1; i<=NF-5; i++) printf $i " "; print ""}')

  if [[ -z $last_uuid_v3 ]]; then
    echo "No previous UUID_V3 in log."
  else
    echo "$last_uuid_v3"
  fi

  if [[ -z $last_uuid_v4 ]]; then
    echo "No previous UUID_V4 in log."
  else
    echo "$last_uuid_v4"
  fi
}

#Variables for later (generate_x is to allow the script to fill in output_name / uuid3_name)
output_name=""
uuid3_name=""
generate_uuid_4=false
generate_uuid_3=false
count_size_child_select=false
directory_files="_Directory"

#Getopts, allows user to use flags and to allow for a user chosen output file and customisation of uuid3_name
while getopts ":abchi:n:o:l" opt; do
  case ${opt} in
    a)
      generate_uuid_4=true
      ;;
    b)
      generate_uuid_3=true
      ;;
    c)
      count_size_child_select=true
      ;;
    h)
      command_help
      ;;
    i) directory_files=$OPTARG
      ;;
    n)
      uuid3_name=$OPTARG
      ;;
    o)
      output_name=$OPTARG
      ;;
    l)
      echo "Last UUIDs created were:"
      uuid_check
      ;;
    \?)
      echo "Invalid option: -${OPTARG}"
      exit 1
      ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
  esac
done

#Function to generate UUID v4
uuid_v4() {
  #16 random bytes
  random=$(xxd -p -l 16 /dev/urandom)

  #Sets the bits for a UUID v4
  random="${random:0:12}4${random:13:3}${random:16:7}a${random:20:12}"

  #Adds the - in correct places
  uuid4_print="${random:0:8}-${random:8:4}-${random:12:4}-${random:16:4}-${random:20:12}"

  #checks for collisions from log file. Print UUID V4 to terminal (and file if required).
  if (grep -q "$uuid4_print" ".utilLogFile"); then
    echo "There has been a collision! This UUID has been used before, please try again!"
    echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') [$(whoami)] attempted to create a UUID V4 but received a collision warning." >> .utilLogFile
    else
      if [[ -n $output_name ]]; then
      echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') UUID_V4 = $uuid4_print run by [$(whoami)] and saved to file: $output_name" >> .utilLogFile
      echo "$uuid4_print - This has been saved to the file name $output_name"
      echo "$uuid4_print" >> "$output_name"
    else
      echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') UUID_V4 = $uuid4_print run by [$(whoami)] and has not been saved" >> .utilLogFile
      echo "$uuid4_print"
    fi
  fi
  }

#Function to generate UUID v3.
uuid_v3() {
  #Checks if a user has passed a name into script, if not it will use 'frankperkiss.co.uk'
  if [[ -n $uuid3_name ]]; then
    name=$uuid3_name
  else
    name="frankperkiss.co.uk"
  fi
  #namespace uuid generated from uuid_v4
  namespace_uuid="b5992ac9-df23-4116-f2fb-11aa11a213c7"

  #Namespace to binary. sed to remove dashs.
  namespace_binary=$(echo -n "$namespace_uuid" | sed 's/-//g' | xxd -r -p)

  #Name to binary
  name_binary=$(echo -n "$name" | xxd -p -c 256)

  #Puts namespace and name (binary together and hashs using MD5)
  hash=$(echo -n "$namespace_binary$name_binary" | md5sum | head -c 32)

  #Sets the bits for UUID v3
  hash="${hash:0:12}3${hash:13:3}${hash:16:7}a${hash:20:12}"

  #Adds the - in correct places
  uuid3_print="${hash:0:8}-${hash:8:4}-${hash:12:4}-${hash:16:4}-${hash:20:12}"

  #Checks for collisions from log file. Print UUID V3 to terminal (and file if required).
  if (grep -q "$uuid3_print" ".utilLogFile"); then
    echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') [$(whoami)] attempted to create a UUID V3 but received a collision warning." >> .utilLogFile
    echo "There has been a collision! This UUID has been used before, please try again, perhaps using the -n flag"
    else
      if [[ -n $output_name ]]; then
      echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') UUID_V3 = $uuid3_print run by [$(whoami)] and saved to file: $output_name" >> .utilLogFile
      echo "$uuid3_print - This has been saved to the file name $output_name"
      echo "$uuid3_print" >> "$output_name"
    else
      echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') UUID_V3 = $uuid3_print run by [$(whoami)] and has not been saved" >> .utilLogFile
      echo "$uuid3_print"
    fi
  fi
  }

count_size() {
  dir="$1"
  declare -A sizes
  declare -A counts

  #for storing longest name, shortest name, max len and min len - set to 999999 because I have no otther way of doing it?
  file_name_short_dir=""
  file_name_long_dir=""
  file_name_max_dir=0
  file_name_min_dir=999999

  #Gets all file extensions and sizes and adds them to an array as declared above.
  while IFS= read -r file; do
    file_counter=$((file_counter + 1))
    ext="${file##*.}"
    file_name=$(basename "$file")
    file_name_len=$(echo -n "$file_name" | wc -m)

    #updates the shortest file name if its shorter, this is why it is set to 999999
    if (( file_name_len < file_name_min_dir )); then
      file_name_short_dir="$file_name"
      file_name_min_dir=$file_name_len
    fi

    #updates the longest file name if longer
    if (( file_name_len > file_name_max_dir )); then
      file_name_long_dir="$file_name"
      file_name_max_dir=$file_name_len
    fi

    #file extension? Yea, good.. if not then no_extension!
    if [[ "$file" != *"."* ]]; then
      ext="no_extension"
    fi

    #get file size
    size=$(stat -c %s "$file")

    #adding the size to array and also the count of times it has seen extension
    sizes["$ext"]=$((sizes["$ext"] + size))
    counts["$ext"]=$((counts["$ext"] + 1))
  done < <(find "$dir" -type f)

  #print out results and possibly add them to an output file
if [[ -n $output_name ]]; then
  echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') directory check run by [$(whoami)] and saved to file: $output_name" >> .utilLogFile
  echo "The directory check has been saved to the file name $output_name"

  echo "Directory: $dir" >> "$output_name"
  echo "Extension         Count         Total Size" >> "$output_name"
  for ext in "${!sizes[@]}"; do
    printf "%-18s %-12d %s\n" "$ext" "${counts[$ext]}" "$(numfmt --to=iec "${sizes[$ext]}")" >> "$output_name"
  done
  echo "" >> "$output_name"
  echo "Total space used by $dir: $(numfmt --to=iec "$(du -sb "$dir" | cut -f1)")" >> "$output_name"
  echo "Longest file in $dir is: $file_name_long_dir and has a length of: $file_name_max_dir" >> "$output_name"
  echo "Shortest file name in $dir is: $file_name_short_dir and has a length of: $file_name_min_dir" >> "$output_name"
  echo "" >> "$output_name"
  echo "" >> "$output_name"
  echo "" >> "$output_name"
  echo "Directory: $dir"
  echo "Extension         Count         Total Size"
  for ext in "${!sizes[@]}"; do
    printf "%-18s %-12d %s\n" "$ext" "${counts[$ext]}" "$(numfmt --to=iec "${sizes[$ext]}")"
  done
  echo ""
  echo "Total space used by $dir: $(numfmt --to=iec "$(du -sb "$dir" | cut -f1)")"
  echo "Longest file in $dir is: $file_name_long_dir and has a length of: $file_name_max_dir"
  echo "Shortest file name in $dir is: $file_name_short_dir and has a length of: $file_name_min_dir"
  echo ""
  echo ""
  echo ""
    else
      echo "$(date '+%d-%m-%y') $(date '+%H:%M:%S') directory check run by [$(whoami)] and has not been saved to a file" >> .utilLogFile
      echo "The directory check has been saved to the file name $output_name"
  	  echo "Directory: $dir"
      echo "Extension         Count         Total Size"
      for ext in "${!sizes[@]}"; do
        printf "%-18s %-12d %s\n" "$ext" "${counts[$ext]}" "$(numfmt --to=iec "${sizes[$ext]}")"
      done
      echo ""
      echo "Total space used by $dir: $(numfmt --to=iec "$(du -sb "$dir" | cut -f1)")"
      echo "Longest file in $dir is: $file_name_long_dir and has a length of: $file_name_max_dir"
      echo "Shortest file name in $dir is: $file_name_short_dir and has a length of: $file_name_min_dir"
      echo ""
      echo ""
      echo ""
  fi
}

#uses count size function on each child directory
count_size_child(){
  if [ -d "$directory_files" ]; then
    echo "Directory: $directory_files. Please wait, this can take a while..."

    #finds the child directories
    for dir in "$directory_files"/*; do
      if [ -d "$dir" ]; then
        count_size "$dir"
      fi
    done

  else
    echo "Directory $directory_files does not exist!!"
  fi
}

#Here to allow uuid generation to work in with getopts.
if $generate_uuid_4; then
    uuid_v4
fi

if $generate_uuid_3; then
  uuid_v3
fi

if $count_size_child_select; then
  count_size_child
fi
