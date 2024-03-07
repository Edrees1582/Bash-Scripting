#!/bin/bash

checking_date="$(date)"
disk_recommedations=""
memory_recommedations=""
system_updates_recommedations=""
report="-----------------------------------\n
*****************************
     System health check
*****************************
Current date & time: ${checking_date}\n
Hostname: $(hostname)
Uptime: $(uptime -p)\n\n"

usage() {
  echo ""
  echo "This is a script that checks the health of the system."
  echo "It checks for disk space, memory usage, running services, and recent system updates."
  echo "It will output a health report along with any recommendations for actions."
  echo ""
  echo "Usage: $0 [-d|--disk-space] [-m|--memory-usage] [-r|--running-services] [-u|--recent-system-updates] [-h|--help]"
  echo "Options:"
  echo "  -d, --disk-space             Check disk space usage and provide recommendations."
  echo "  -m, --memory-usage           Check memory usage and provide recommendations."
  echo "  -r, --running-services       Check running services and provide recommendations."
  echo "  -u, --recent-system-updates  Check recent system updates and provide recommendations."
  echo "  -h, --help                   Display this help message."
  exit 0
}

check_disk() {
  echo "Checking disk usage..."
  report+="Checking disk usage...\n\n"
  report+="$(printf "%s\t%s\t%s\t%s\n", "Filesystem" "Mounted on" "Used" "Available")"
  echo ""
  disk_info="$(df -h)"
  echo "$disk_info"
  
  while read -r line
    do
      usage="$(echo "$line" | awk '{ print $5 }' | sed 's/%//')"
	  disk="$(echo "$line" | awk '{ print $1 $6 }' | sed 's/%//')"
      report+="$(echo "$line" | awk '{print $1"\t"$6"\t"$5"\t"$4}')"
      if (( "$usage" < "85" ))
        then
          report+="\t----- HEALTHY\n"
      elif (( "$usage" < "95" ))
        then
		  report+="\t----- WARNING\n"
          disk_recommedations+="$disk disk space usage is high! Consider freeing up space.\n"
	  elif [[ "$usage" -le "100" ]]
        then
		  report+="\t----- CRITICAL\n"
          disk_recommedations+="$disk disk space usage is very high! Consider freeing up space.\n"
      fi
  done < <(${disk_info} | awk 'NR>1')
  echo "..................."
}

check_memory() {
  echo "Checking memory usage..."
  mem="$(free -h)"
  echo "$mem"
  report+="Checking memory usage...\n$mem\n\n"
  while read -r line
    do
      usage="$(echo "$line" | awk '{ print $3/$2 * 100 }' | cut -d. -f1)"
        if [[ "$usage" -ge "80" ]]
  	      then
            memory_recommedations+="Memory usage is high! Consider optimizing or adding more RAM."
        fi
  done < <(${mem} | awk 'NR==2')
  echo "..................."
}

check_running_services() {
  echo "Checking running services..."
  runs="$(systemctl list-units -a --state=running | head -n -1)"
  echo "$runs"
  report+="Checking running services...\n$runs\n\n"
  echo "..................."
}

check_recent_system_updates() {
  echo "Checking recent system updates..."
  rec="$(grep -B 1 -A 2 "apt-get upgrade" /var/log/apt/history.log)"
  echo "$rec\n\n"
  report+="Checking recent system updates...\n$rec\n\n"
  count="$(apt list --upgradable | grep -c upgradable)"
  if [[ "$count" -gt 0 ]]
    then
      system_updates_recommedations+="There are $count updates available. Consider updating the system."
  fi
  echo "..................."
}

generate_report() {
  if [[ ! -z "$disk_recommedations" || ! -z "$memory_recommedations" || ! -z "$system_updates_recommedations" ]]
    then
	  report+="Recommendations:\n"
  fi
  
  if [[ ! -z "$disk_recommedations" ]]
    then
	  report+="$disk_recommedations\n-----------------\n"
  fi
  
  if [[ ! -z "$memory_recommedations" ]]
    then
	  report+="$memory_recommedations\n-----------------\n"
  fi
  
  if [[ ! -z "$system_updates_recommedations" ]]
    then
	  report+="$system_updates_recommedations\n-----------------\n"
  fi
  
  report+="\n-----------------------------------"

  echo "health report generated into health_report.txt"
  echo -e "${report}" >> health_report.txt
}

if [[ $# -eq 0 ]]
  then
    echo "No flags provided!!"
    usage
fi

while [[ $# -gt 0 ]]
  do
    case "$1" in
      -d|--disk-space)
	    check_disk
	    shift
	    ;;
	  -m|--memory-usage)
	    check_memory
	    shift
	    ;;
	  -r|--running-services)
	    check_running_services
	    shift
	    ;;
	  -u|--recent-system-updates)
	    check_recent_system_updates
	    shift
	    ;;
	  -h|--help)
	    usage
	    exit 0
	    ;;
	  *)
	    echo "Unknown option $1"
	    exit 1
	    ;;
    esac
done

generate_report