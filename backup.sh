#!/bin/bash

backup_date=$(date +%Y%m%d-%H%M%S)
start_date=$(date)

restore="false"
encrypt="false"

usage() {
  echo ""
  echo "This is a script to do backups for user-specified directories."
  echo "It performs compression, encryption if needed, backup restoration, and error handling."
  echo "The backup status will be reported and saved in 'backup_log.txt'."
  echo ""
  echo "Usage: $0 [-r|--restore <backup_file>] [-e|--encrypt] [-d|--directories <directory_list>] [-D|--destination <backup_destination>] [-c|--comments <backup_comments>] [-h|--help]"
  echo "Options:"
  echo "  -r, --restore <backup_file>   Restore from the specified backup file."
  echo "  -e, --encrypt                Enable encryption for the backup."
  echo "  -d, --directories <directory_list>"
  echo "                               Specify a space-separated list of directories to backup."
  echo "  -D, --destination <backup_destination>"
  echo "                               Specify the destination for the backup."
  echo "  -c, --comments <backup_comments>"
  echo "                               Add comments about the backup."
  echo "  -h, --help                   Display this help message."
  exit 0
}

validate_directories() {
  directories_arr=()
  for directory in $directories
    do directories_arr+=($directory)
  done
  
  while true
    do
	  if [[ -z $directories ]]
	    then
		  read  -p "Enter directories: " directories
	  fi
	  
	  directories_arr=()
	  for directory in $directories
	    do directories_arr+=($directory)
	  done
	  
	  for directory in ${directories_arr[@]}
	    do
		  if [[ ! -d $directory ]]
	        then
			  directories=""
		      echo "Please enter valid directories."
			  valid="false"
			  break
			else
			  valid="true"
		  fi
	  done
	  
      if [[ $valid == "true" ]]
  	    then
		  break
	  fi
  done
}

validate_destination() {
  if [[ -z ${destination} ]]
    then
      destination="/home/backups"
	else
	  [[ ! -d ${destination} ]] && mkdir ${destination}
  fi

  [[ ! -d ${destination} ]] && mkdir ${destination}
}

validate_restore_file() {
  while true
    do
	  if [[ ! -f $restore_file ]]
	    then
		  echo "Please enter a valid backup."
		else break
	  fi
	  read  -p "Enter a backup file: " restore_file
  done  
}

check_status() {
  if [[ $? -eq 0 ]]
    then
      status="Successful"
    else
      status="Unsuccessful"
	  exit 1
  fi
}

print_log() {
  log="-----------------------------------\n
  Started at: ${start_date}\n
  Backup file: ${file_name}\n
  Backup size: $(wc -c ${destination}/${file_name}.gz | cut -d' ' -f1) bytes\n
  Backedup directories: ${directories}\n
  Destination: ${destination}\n
  Comment: ${comments}\n
  Status: ${status}\n
  Finished at: ${finish_date}\n-----------------------------------"

  echo -e ${log} >> backup_log.txt
}

perfom_backup() {
  validate_directories
  validate_destination
  if [[ -z ${comments} ]]
      then
        read -p "Enter comments about your backup: " comments  
  fi
  if [[ "$encrypt" == "true" ]]
    then
      echo "Enter a password to backup:"
      read -s password
      #tar -zcvf ${destination}/${file_name} ${directories} && openssl enc -aes-256-cbc -pbkdf2 -salt -in ${destination}/${file_name} -out ${destination}/${file_name}.enc -k $password
      tar -cvf ${destination}/${file_name} ${directories} && pigz ${destination}/${file_name} && openssl enc -aes-256-cbc -pbkdf2 -salt -in ${destination}/${file_name} -out ${destination}/${file_name}.enc -k $password | check_status
	  check_status
	  rm ${destination}/${file_name}
      file_name=${file_name}.enc
    else
      ##tar -zcvf ${destination}/${file_name} ${directories}
	  tar -cvf ${destination}/${file_name} ${directories} && pigz ${destination}/${file_name}
	  check_status
  fi
  finish_date=$(date)
  print_log
}

perfom_restore() {
  validate_restore_file
  if [[ "${restore_file##*.}" == "enc" ]]
    then
      echo "Enter the password to restore backup:"
      read -s password
      openssl enc -aes-256-cbc -d -pbkdf2 -in ${restore_file} -out $(realpath ${restore_file%.enc*}) -k $password
  fi
  base_file="$(basename $restore_file)"
  [[ ! -d "/home/restore_backup" ]] && mkdir "/home/restore_backup"
  [[ ! -d "/home/restore_backup/${base_file%.tar*}" ]] && mkdir "/home/restore_backup/${base_file%.tar*}"
  #tar -xzvf $(realpath ${restore_file%.enc*}) -C "/home/restore_backup/${base_file%.tar*}" && rm $(realpath ${restore_file%.enc*})
  pigz -d $(realpath ${restore_file%.enc*}) && tar -xvf $(realpath ${restore_file%.gz*}) -C "/home/restore_backup/${base_file%.tar*}"
}

while [[ $# -gt 0 ]]
  do
    case "$1" in
	  -r|--restore)
	    restore_file="$2"
	    restore="true"
	    shift 2
	    ;;
      -e|--encrypt)
	    encrypt="true"
	    shift
	    ;;
	  -d|--directories)
	    directories="$2"
	    shift 2
	    ;;
	  -D|--destination)
	    destination="$2"
	    shift 2
	    ;;
	  -c|--comments)
	    comments="$2"
	    shift 2
	    ;;
	  -h|--help)
	    usage
	    exit 0
	    ;;
	  *)
	    echo "Unknown option $1\n"
	    exit 1
	    ;;
    esac
done

file_name=$(hostname)_${backup_date}.tar

if [[ "$restore" == "false" ]]
  then
	time perfom_backup
  else
    time perfom_restore
fi