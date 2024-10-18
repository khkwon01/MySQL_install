#!/bin/sh
#set -vx


AUTHOR="kihyuk (kwon.kihyuk@oracle.com)"
VERSION="8.4.2"
MYSQL="MySQL_"${VERSION}
MSHELL="MySQL_Shell_"${VERSION}

ERR=0

# Setup general language type
export LANG=en_US.UTF-8

# Used for a better dialog visualization on putty
export NCURSES_NO_UTF8_ACS=1

# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

export working_dir="$( dirname $0 )"
if [[ ! ${working_dir} =~ ^/ ]]; then
    working_dir="$( pwd)/${working_dir}"
fi

export log_file="${working_dir}/$(basename -s .sh $0).log"
export sw_dir="${working_dir}/pkg"

export MOS_LINK_SRV_TAR='https://updates.oracle.com/Orion/Services/download/p36869167_840_Linux-x86-64.zip?aru=25760694&patch_file=p36869167_840_Linux-x86-64.zip'
export MOS_LINK_SHELL_TAR='https://updates.oracle.com/Orion/Services/download/p36789146_840_Linux-x86-64.zip?aru=25736049&patch_file=p36789146_840_Linux-x86-64.zip'
export DEV_LINK_SRV_TAR='https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.2-linux-glibc2.28-x86_64.tar.xz'
export DEV_LINK_SHELL_TAR='https://dev.mysql.com/get/Downloads/MySQL-Shell/mysql-shell-8.4.1-1.el8.x86_64.rpm'
export CHK_DL_MYSQL="${sw_dir}/mysql_download_type.lst"
export PUBLIC_ReleaseNote='https://dev.mysql.com/doc/relnotes/mysql/8.4/en/news-8-4-2.html'
export KOREA_ReleaseNote='https://github.com/khkwon01/MySQL_install/blob/master/releases/8.4.0.md'

export AIRPORT_DB='https://downloads.mysql.com/docs/airport-db.tar.gz'

#####################################################
# FUNCTIONS
#####################################################

# Display message
display_msg() {
    dialog --title "$1" \
	--backtitle "Message Display" \
        --no-collapse \
	--msgbox "$2" 0 0
}

# Exit from errors
stop_execution_for_error () {
# first parameter is the exiut code
# second parameter is the error message

    ERR=$1
    ERR=${ERR:=1}

    MSG=$2
    MSG=${MSG:="Generic error"}
    echo "$(date) - ERROR - ${MSG}" |tee -a ${log_file}
    echo "$(date) - INFO - End" >> ${log_file}

    exit $ERR
}

install_mysql_utilites () {
    ERR=0

    echo "$(date) - INFO - Start function ${FUNCNAME[0]}" >> ${log_file}

    # Install MySQL clients
    echo "$(date) - INFO - Install MySQL client and Shell on $client" |tee -a ${log_file}    

    MYSQL_TYPE=`cat ${CHK_DL_MYSQL}`

    if [ "${MYSQL_TYPE}" == "commerial" ];
    then	    
       if [ ! -f "${sw_dir}/${MSHELL}.zip" ]
       then
          ERR=1
          msg="ERROR - Install Err due to not exist ${MSHELL}.zip"
          echo "$(date) - ${msg}" |tee -a ${log_file}
          display_msg "Install Error" "${msg}"       
          return $ERR
       fi	    

       sudo rm -f ${sw_dir}/*x86_64.rpm
       sudo unzip "${sw_dir}/${MSHELL}.zip" -d "${sw_dir}/" *x86_64.rpm
       sudo rm -f ${sw_dir}/*debuginfo*.rpm 
       sudo yum -y install ${sw_dir}/*shell-commercial*x86_64.rpm
    else 
       sudo yum -y install ${sw_dir}/*shell-${VERSION}-*x86_64.rpm
    fi


    ERR=$?

    if [ $ERR -eq 0 ]
    then
       msg="MySQL shell installation completed"
       display_msg "Client installation" "${msg}"
       echo "$(date) - INFO - ${msg}" >> ${log_file}
    else
       msg="MySQL shell installation failed"
       display_msg "Client installation" "${msg}"
       echo "$(date) - INFO - ${msg}(${ERR})" >> ${log_file}
    fi



    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}

    return $ERR
}

install_mysql_server () {
    ERR=0

    MYSQL_TYPE=`cat ${CHK_DL_MYSQL}`

    echo "$(date) - INFO - Start $(echo ${FUNCNAME[0]})" |tee -a ${log_file}

    echo "$(date) - INFO - Create OS group mysqlgrp on this server" |tee -a ${log_file}
    sudo groupadd mysqlgrp
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during OS group mysqlgrp creation"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file} 
       return $ERR
    fi

    echo "$(date) - INFO - Create OS user mysqluser on this server" |tee -a ${log_file}
    sudo useradd -r -g mysqlgrp -s /bin/false mysqluser
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during OS user mysqluser creation"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Create directoy structure on this server" |tee -a ${log_file}
    sudo mkdir -p /mysql/ /mysql/etc /mysql/data /mysql/log /mysql/temp /mysql/binlog
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during Directoy structure creation"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    sudo chown -R mysqluser:mysqlgrp /mysql
    

    if [ "${MYSQL_TYPE}" == "commerial" ];
    then
       rm -f ${sw_dir}/*x86_64.tar.xz
       sudo unzip ${sw_dir}/${MYSQL}.zip -d ${sw_dir} *.tar.xz
    fi

    echo "$(date) - INFO - Extract MySQL Enterprise tar on this server" |tee -a ${log_file}
    cd /mysql
    sudo tar xf ${sw_dir}/*x86_64.tar.xz 
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during MySQL Enterprise tar extraction"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    cd /mysql
    sudo mv $( basename -s .tar.xz ${sw_dir}/*x86_64.tar.xz ) ${MYSQL}

    echo "$(date) - INFO - Create symbolic link to MySQL Enterprise installation on this server" |tee -a ${log_file}
    cd /mysql
    sudo ln -s ${MYSQL} mysql-latest
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during symbolic link creation"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Copy my.cnf for commercial installation on this server" |tee -a ${log_file}
    mycnf="https://github.com/khkwon01/MySQL-setup/raw/main/mycnf/my.cnf"
    cd /mysql/etc/
    sudo wget --secure-protocol=auto ${mycnf}
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during my.cnf copy into /mysql/etc"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Download systemctl auto start script" |tee -a ${log_file}
    cd /mysql
    mystart="https://raw.githubusercontent.com/khkwon01/MySQL-setup/main/systemctl/mysqld-advanced.service"
    sudo wget --secure-protocol=auto ${mystart}
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during download of systemctl mysql script"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Set ownerships to MySQL Enterprise directories on this server" |tee -a ${log_file}
    sudo chown -R mysqluser:mysqlgrp /mysql
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during ownerships set"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Set permissions to MySQL Enterprise directories on this server" |tee -a ${log_file}
    sudo chmod -R 770 /mysql
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during permissions set"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Initialize MySQL Enterprise on this server" |tee -a ${log_file}
    sudo /mysql/mysql-latest/bin/mysqld --defaults-file=/mysql/etc/my.cnf --initialize --user=mysqluser
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during MySQL initialize"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Find MySQL temp root password" |tee -a ${log_file}
    TMPPASS=$(sudo awk '/temporary password/ {print $NF}' /mysql/log/err_log.log)
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during finding MySQL root password"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    # if you want to disable permantly, you modify /etc/selinux/config file
    echo "$(date) - INFO - Change enforcing mode of selinux to permissive" |tee -a ${log_file} 
    sudo setenforce 0
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during OS selinux mode change"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Configure systemd startup for MySQL Enterprise on this server" |tee -a ${log_file}
    sudo mv /mysql/mysqld-advanced.service /usr/lib/systemd/system/
    sudo chmod 644 /usr/lib/systemd/system/mysqld-advanced.service
    sudo systemctl enable mysqld-advanced.service
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during systemd startup configuration"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Start MySQL Enterprise on this server" |tee -a ${log_file}
    sudo systemctl start mysqld-advanced.service
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during MySQL server start"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Get the password of root from user" |tee -a ${log_file}
    export PFILE=$(mktemp  --tmpdir=${working_dir} temp_pas_XXXXXX)
    dialog \
       --title "root password setup" \
       --clear \
       --no-collapse \
       --passwordbox "passwd(default:Welcome#1)" 10 50 2> $PFILE
    
    exit_status=$?

    case $exit_status in
       0)
           PASS=$(cat $PFILE) 
	   if [ -z $PASS ]
           then
	      PASS="Welcome#1"
	   fi
	   ;;	
       1)
	   PASS="Welcome#1" 
	   ;;
    esac

    rm -f $PFILE
    clear
    echo "$(date) - INFO - Change root password from temp password" |tee -a ${log_file}
    sudo /mysql/mysql-latest/bin/mysql -uroot -h127.0.0.1 -P3306 --connect-expired-password -p${TMPPASS} -e "ALTER USER root@localhost IDENTIFIED BY '${PASS}'"
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during MySQL root password change"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Add MySQL exec path to env on this server" |tee -a ${log_file}
    echo 'export PATH=/mysql/mysql-latest/bin:$PATH' >> ~/.bashrc
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="error during adding MySQL exec path"
       display_msg "Server installation" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - Add MySQL socket path" |tee -a ${log_file}
    echo 'export MYSQL_UNIX_PORT=/mysql/temp/mysql.sock' >> ~/.bashrc

    source $HOME/.bashrc

    display_msg "Server installation" "MySQL installation succeed.."
    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}

    return $ERR
}

connect_mysql_server () {
 
    ERR=0

    echo "$(date) - INFO - Start function ${FUNCNAME[0]}" >> ${log_file}
    
    DB_IP="127.0.0.1"
    DB_PORT="3306"
    DB_USER="root"
    DB_PASS=""

    exec 3>&1

    result=$(dialog \
        --title "Database info" \
	--backtitle "Connection test" \
        --clear \
        --no-collapse \
        --cancel-label "Exit" \
        --form "Put MySQL Server Info" 10 60 0 \
        "ip  (↑): " 1 1 "${DB_IP}"   1 12 25 0 \
	"port   : " 2 1 "${DB_PORT}" 2 12 10 0 \
        "user   : " 3 1 "${DB_USER}" 3 12 25 0 \
	"pass(↓): " 4 1 "${DB_PASS}" 4 12 25 0 \
	2>&1 1>&3)

    exit_status=$?

    exec 3>&-   

    case $exit_status in
    $DIALOG_CANCEL)
        clear
        echo "$(date) - INFO - Scripts menu end" >> ${log_file}
        return $ERR
        ;;
    $DIALOG_ESC)
        clear
        echo "$(date) - INFO - Scripts menu cancelled" >> ${log_file}
        return $ERR
        ;;
    esac

    echo $result >> ${log_file}

    DB_IP=`echo $result | cut -d " " -f 1 -s`
    DB_PORT=`echo $result | cut -d " " -f 2 -s`
    DB_USER=`echo $result | cut -d " " -f 3 -s`
    DB_PASS=`echo $result | cut -d " " -f 4 -s`
    msg=`echo "ip:${DB_IP}\nport:${DB_PORT}\nuser:${DB_USER}\npass:${DB_PASS}\n"`
   
    if [ -z "${DB_IP}" ] || [ -z "${DB_PORT}" ] || [ -z "${DB_USER}" ] || [ -z "${DB_PASS}" ] 
    then
       display_msg "Error - Wrong info" "${msg}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
       return $ERR
    fi

    echo "$(date) - INFO - DB INFO - ${msg}" >> ${log_file}

    echo "$(date) - INFO - test connectivity for MySQL" >> ${log_file}
    result=$(sudo /mysql/mysql-latest/bin/mysql -u${DB_USER} -h${DB_IP} -P${DB_PORT} -p${DB_PASS} -e "show databases")
    ERR=$?
    if [ $ERR -ne 0 ]
    then
       msg="The database can't be connect using your db info"
       display_msg "Error - Connection" "${msg}\n${result}"
       echo "$(date) - ERROR - ${msg}" >> ${log_file}
    else 
       display_msg "Connection success" "${result}"
       echo "$(date) - INFO - Connection test is ok" >> ${log_file}
    fi

    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}
}

load_data () {
    
    ERR=0

    echo "$(date) - INFO - Start function ${FUNCNAME[0]}" >> ${log_file}

    sudo rm -f ${sw_dir}/airportdb.tar.gz
    echo "$(date) - INFO - Download of airport db... please wait..." >> ${log_file}
    wget --progress=dot --secure-protocol=auto -O "${sw_dir}/airportdb.tar.gz" ${AIRPORT_DB} 2>&1 | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | dialog --backtitle "Data Download" --gauge "Download airport data from repo" 10 60

    cd ${sw_dir}
    sudo rm -rf ${sw_dir}/airport-db
    sudo tar xf ${sw_dir}/airportdb.tar.gz 
    DB_DOWNLOAD_STATUS=$?

    if [ $DB_DOWNLOAD_STATUS -ne 0 ] ; then
       msg="ERROR - Error during the download of airport db"
       echo "$(date) - ${msg}" |tee -a ${log_file}
       display_msg "Download Error" "${msg}"

       return $DB_DOWNLOAD_STATUS
    fi

    clear
    sudo mysqlsh -uroot -p -- util loadDump ${sw_dir}/airport-db --resetProgress --threads 10 2>&1
    ERR=$?
    if [ $ERR -ne 0 ] ; then
       msg="ERROR - Error during loading airport db"
       echo "$(date) - ${msg}" |tee -a ${log_file}
       display_msg "Loading Data Error" "${msg}"

       return $ERR
    fi   

    display_msg "Download Completed" "The airport db load is completed"

    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}
}

release_note () {
    echo "$(date) - INFO - Start function ${FUNCNAME[0]}" >> ${log_file}

    display_msg "${VERSION} Release Note" "\n[English]\n${PUBLIC_ReleaseNote}\n"

    echo "$(date) - INFO - English release: ${PUBLIC_ReleaseNote}" >> ${log_file}

    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}
}

download_software_from_MOS () {
    ERR=0

    echo "$(date) - INFO - Start function ${FUNCNAME[0]}" >> ${log_file}

    exec 3>&1

    result=$(dialog \
        --title "MOS Info" \
        --clear \
	--no-collapse \
        --cancel-label "Exit" \
        --form "Put MOS info of support.com" 10 60 0 \
	"id  (↑): " 1 1 "" 1 12 25 0 \
	"pass(↓): " 2 1 "" 2 12 25 0 \
    2>&1 1>&3)

    exit_status=$?

    exec 3>&-

    case $exit_status in
    $DIALOG_CANCEL)
        clear
        echo "$(date) - INFO - Scripts menu end" >> ${log_file}	    
        return $ERR
        ;;
    $DIALOG_ESC)
        clear
        echo "$(date) - INFO - Scripts menu cancelled" >> ${log_file}           
        return $ERR
        ;;
    esac

    MOS_USERNAME=`echo $result | cut -d " " -f 1`
    MOS_PASSWORD=`echo $result | cut -d " " -f 2 -s`

    if [ "${#MOS_USERNAME}" -lt 2 ] || [ "${#MOS_PASSWORD}" -lt 2 ]
    then
        ERR=1
	msg="MOS info didn't get from user input"
        display_msg "Input Error" "${msg}"
	stop_execution_for_error $ERR "${msg}"
    fi

    cd ${working_dir}
    # Cookie file for the authentication
    export COOKIE_FILE=$(mktemp  --tmpdir=${working_dir} wget_sh_XXXXXX)
    if [ $? -ne 0 ] || [ -z "$COOKIE_FILE" ]
    then
        ERR=1
        stop_execution_for_error $ERR "Temporary cookie file creation failed."
    fi

    # Authentication on MOS (https://support.oracle.com)
    #read -p 'MOS (https://support.oracle.com) Username: ' MOS_USERNAME
    
    #wget  --secure-protocol=auto --save-cookies="${COOKIE_FILE}" --keep-session-cookies  --http-user "${MOS_USERNAME}" --ask-password  "https://updates.oracle.com/Orion/Services/download" -O /dev/null -a ${log_file}

    wget  --secure-protocol=auto --save-cookies="${COOKIE_FILE}" --keep-session-cookies  --http-user "${MOS_USERNAME}" --http-password "${MOS_PASSWORD}"  "https://updates.oracle.com/Orion/Services/download" -O /dev/null -a ${log_file}

    if [ $? -ne 0 ]
    then
        ERR=1
	msg="the given credentials is wrong"
	display_msg "Auth Error" "${msg}"
	stop_execution_for_error $ERR $msg
    fi

    echo "$(date) - INFO - Download of MySQL tar repo... please wait..." >> ${log_file}
    wget --progress=dot --load-cookies="$COOKIE_FILE" --save-cookies="$COOKIE_FILE" --keep-session-cookies ${MOS_LINK_SRV_TAR} -O "${sw_dir}/${MYSQL}.zip" 2>&1 | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | dialog --backtitle "MySQL configuration" --gauge "Download MySQL binary tar (${VERSION})" 10 60
    
#    SRV_TAR_PKG_DOWNLOAD_PID=$!
#    wait ${SRV_TAR_PKG_DOWNLOAD_PID}
    SRV_TAR_PKG_DOWNLOAD_STATUS=$?
    if [ $SRV_TAR_PKG_DOWNLOAD_STATUS -ne 0 ] ; then
       msg="ERROR - Error during the download of MySQL server"
       echo "$(date) - ${msg}" |tee -a ${log_file}
       display_msg "Download Error" $msg
    fi

    echo "$(date) - INFO - Download of MySQL rpms repo... please wait..." >> ${log_file}
    wget --progress=dot --load-cookies="$COOKIE_FILE" --save-cookies="$COOKIE_FILE" --keep-session-cookies ${MOS_LINK_SHELL_TAR} -O "${sw_dir}/${MSHELL}.zip" 2>&1 | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | dialog --backtitle "MySQL configuration" --gauge "Download MySQL shell (${VERSION})" 10 60

    SHL_RPM_DOWNLOAD_STATUS=$?
    if [ $SHL_RPM_DOWNLOAD_STATUS -ne 0 ] ; then
       msg="ERROR - Error during the download of MySQL shell"
       echo "$(date) - ${msg}" |tee -a ${log_file}
       display_msg "Download Error" $msg
    fi    

    sudo rm -f "${COOKIE_FILE}"

    echo "commerial" > ${CHK_DL_MYSQL}

    echo
    echo "$(date) - INFO - All commerial version downloads completed" |tee -a ${log_file}
    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}

    return $ERR
}

download_software_from_Dev () {
    ERR=0

    echo "$(date) - INFO - Start function ${FUNCNAME[0]}" >> ${log_file}

    wget --progress=dot $DEV_LINK_SRV_TAR -O "${sw_dir}/`basename $DEV_LINK_SRV_TAR`" 2>&1 | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | dialog --backtitle "MySQL configuration" --gauge "Download MySQL binary tar (community ${VERSION})" 10 60

    SRV_TAR_PKG_DOWNLOAD_STATUS=$?
    if [ $SRV_TAR_PKG_DOWNLOAD_STATUS -ne 0 ] ; then
       msg="ERROR - Error during the download of MySQL server"
       echo "$(date) - ${msg}" |tee -a ${log_file}
       display_msg "Download Error" $msg
    fi    

    wget --progress=dot $DEV_LINK_SHELL_TAR -O "${sw_dir}/`basename $DEV_LINK_SHELL_TAR`" 2>&1 | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | dialog --backtitle "MySQL configuration" --gauge "Download MySQL shell (community ${VERSION})" 10 60

    SHL_RPM_DOWNLOAD_STATUS=$?
    if [ $SHL_RPM_DOWNLOAD_STATUS -ne 0 ] ; then
       msg="ERROR - Error during the download of MySQL shell"
       echo "$(date) - ${msg}" |tee -a ${log_file}
       display_msg "Download Error" $msg
    fi    

    echo "community" > ${CHK_DL_MYSQL}

    echo "$(date) - INFO - All community version downloads completed" |tee -a ${log_file}
    echo "$(date) - INFO - End function ${FUNCNAME[0]}" >> ${log_file}

    return $ERR
}

test_func () {
    
    #display_msg "test" "This is test message"
    
    #exec 3>&1

    #result=$(dialog \
    #    --title "Dialog test" \
    #    --clear \
    #    --cancel-label "Exit" \
    #    --form "Put MOS info of support.com" 10 60 0 \
    #    "id  : " 1 1 "" 1 12 25 0 \
    #    "pass: " 2 1 "" 2 12 25 0 \
    #2>&1 1>&3)

    #exit_status=$?

    #exec 3>&-

    #echo $result

    echo "10"
    sleep 1
    echo "20"
    sleep 2
    echo "30"
    sleep 3
    echo "40"
    sleep 4
    echo "50"
    sleep 5
    echo "60"
    sleep 6
    echo "70"
    sleep 7
    echo "80"
    sleep 8
    echo "90"
    sleep 9
    echo "100"
}

###################################################################################################
# MAIN
###################################################################################################

echo "$(date) - INFO - Start" >> ${log_file}
echo "$(date) - INFO - Script version ${VERSION}" >> ${log_file}

echo "$(date) - INFO - Check, and if needed install, install pre-requisites" | tee -a ${log_file}

sudo yum -y -q install ncurses-compat-libs dialog wget unzip jq python39-libs 2>&1 >>${log_file}
sudo mkdir -p ${sw_dir} 2>&1 >>${log_file}
sudo chown -R $USER ${sw_dir} 2>&1 >>${log_file}

ERR=$?
if [ $ERR -ne 0 ] ; then
    stop_execution_for_error $ERR "Issues during required software installation"
fi

if [ $OPTIND -eq 1 ]; then
    echo "$(date) - INFO - Interactive mode" >> ${log_file}

    while true
    do
    	exec 3>&1

	selection=$(dialog --keep-tite \
		--backtitle "MySQL ${VERSION} configuration" \
		--title "MySQL configuration menu" \
		--clear  \
		--cancel-label "Exit" \
		--menu "\nEnter follow number to use these commands" 0 0 0\
		"1" "Download install file from oracle" \
		"2" "Install mysql shell" \
		"3" "Install mysql server" \
		"4" "Test connectivity of MySQL" \
		"5" "Load Airport data" \
		"6" "Release Note" \
		2>&1 1>&3)

	# when test, "9" "This Program test" \

        exit_status=$?

        # Close file descriptor 3
        exec 3>&-

	case $exit_status in
        $DIALOG_CANCEL)
            clear
            echo "$(date) - INFO - Interactive menu end" >> ${log_file}
            exit
            ;;
        $DIALOG_ESC)
            clear
            echo "$(date) - INFO - Interactive menu cancelled" >> ${log_file}
            return $ERR
            ;;
        esac

	case $selection in
	1 )
	    dialog --title "choose commercial or community" \
	       --clear \
	       --yesno "\n\ncommercial version : yes\ncommunity version : no" 10 40
	    SEL=$?
	    if [ $SEL -ne 1 ]
            then
	       download_software_from_MOS
	    else
	       download_software_from_Dev
	    fi
	    ;;
        2 ) 
	    clear
	    install_mysql_utilites
	    ;;
        3 )
            clear
	    install_mysql_server
	    result=$?

	    if [ $result -ne 0 ]
	    then
		dialog --title "reinstall mysql" \
		   --clear \
		   --yesno "Does MySQL delete?" 5 30
	        DEL=$?
	        if [ $DEL -ne 1 ] 
		then	
                   sudo systemctl stop mysqld-advanced.service &> /dev/null
                   sudo systemctl disable mysqld-advanced.service &> /dev/null
                   sudo userdel mysqluser &> /dev/null
                   sudo groupdel mysqlgrp &> /dev/null
                   sudo rm -rf /mysql/  &> /dev/null
	        fi
            fi
	    ;;
	4) 
	    connect_mysql_server
	    ;;
	5)
            load_data
            ;;
	6) 
	    release_note
	    ;;
	9 ) 
	    test_func | dialog --backtitle "progress test" --gauge "progress test.." 10 60
	    #read -p "Press ENTER to continue"
	    ;;
	esac

    done
fi

echo "$(date) - INFO - End" >> ${log_file}
exit $ERR
