#!/bin/bash
#
# LI, Zhiqiang(lee.luoman@gmail.com)
# 2019-10-10
#
Usage(){
    cat <<EOF
Usage:
    $0 --config_ustc       (use_ustc_source)
    $0 --install_ros       (install ros)
    $0 --config_ssh aliasname login_name@login_ip       (config ssh)
    $0 --config_workspace  (config workspace)
    $0 --config_rc_lcoal   (add rc.local file for ubuntu 18.04)
    $0 --install_zmq
    $0 --add_local_systemd path_to_local_script
    $0 -h                  (Display Usage)
EOF
    exit 1
}

function use_ustc_source {
  if [ "$1" == "recovery" ]; then
    newestbackfile=$(ls /etc/apt | grep .bak | tail -n 1)
    echo "recovery source.list with /etc/apt/$newestbackfile"
    sudo cp /etc/apt/$newestbackfile /etc/apt/sources.list
  elif [ "$1" == "arm" ]; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.$(date "+%Y%m%d%H%M%S").bak
    echo "backup source.list to /etc/apt/sources.list.$(date "+%Y%m%d%H%M%S").bak"
    sudo sh -c "cat > /etc/apt/sources.list" << EOF
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc) main restricted
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-updates main restricted
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc) universe
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-updates universe
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc) multiverse
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-updates multiverse
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-backports main restricted universe multiverse
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-security main restricted
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-security universe
deb http://mirrors.ustc.edu.cn/ubuntu-ports/ $(lsb_release -sc)-security multiverse
EOF
  else
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.$(date "+%Y%m%d%H%M%S").bak
    echo "backup source.list to /etc/apt/sources.list.$(date "+%Y%m%d%H%M%S").bak"    
    sudo sh -c "cat > /etc/apt/sources.list" << EOF
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc) main restricted
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-updates main restricted
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc) universe
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-updates universe
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc) multiverse
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-updates multiverse
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-backports main restricted universe multiverse
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-security main restricted
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-security universe
deb http://mirrors.ustc.edu.cn/ubuntu/ $(lsb_release -sc)-security multiverse
EOF
  fi
  sudo apt update
}

function install_ros {
  if [ "$(lsb_release -sc)"=="bionic" ];
  then
    rosversion="melodic"
  elif [ "$(lsb_release -sc)"=="xenial" ];then
    rosversion="kinetic"
  fi
  echo "current ubuntu version is $(lsb_release -sc)"
  echo "$rosversion is going to be installed, this will take a few minutes ..."
  sudo sh -c 'echo "deb http://mirrors.ustc.edu.cn/ros/ubuntu/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
  sudo apt update
  sudo apt -y install ros-$rosversion-desktop-full
  sudo apt -y install ros-$rosversion-rqt*
  sudo rosdep init
  rosdep update
  echo "#for ros" >> ~/.bashrc
  echo "source /opt/ros/$rosversion/setup.bash" >> ~/.bashrc
  source ~/.bashrc
}

function config_ssh {
  if [ ! -f "$HOME/.ssh/local_rsa.pub" ]; then
    echo "there is no key named 'local_rsa' in ~/.ssh"
    echo "generating 'local_rsa' ssh key..."
    ssh-keygen -t rsa -f ~/.ssh/local_rsa
  fi
  echo "copy local ssh key to remote server $2..."
  ssh-copy-id -i $HOME/.ssh/local_rsa.pub $2
  echo "#for ssh $1" >> ~/.bashrc
  echo "alias $1login='ssh $2'" >> ~/.bashrc
  source ~/.bashrc
}

function config_workspace {
  if [ ! -d "$HOME/robot/cartographer_ws" ]; then
    echo "start to config cartographer workspace..."
    mkdir -p $HOME/robot/cartographer_ws
    sudo apt-get update
    sudo apt-get install -y python-wstool python-rosdep ninja-build
    cd $HOME/robot/cartographer_ws
    wstool init src
    wstool merge -t src https://raw.githubusercontent.com/googlecartographer/cartographer_ros/master/cartographer_ros.rosinstall
    sed -i 's!    version: 1.0.0!    version: master!g' ./src/.rosinstall
    sed -i 's!ceres-solver.googlesource.com!github.com/ceres-solver!g' ./src/.rosinstall
    wstool update -t src
    src/cartographer/scripts/install_proto3.sh
    sudo rosdep init
    rosdep update
    rosdep install --from-paths src --ignore-src --rosdistro=${ROS_DISTRO} -y
    catkin_make_isolated --install --use-ninja
    echo "#for cartographer" >> ~/.bashrc
    echo "alias recompilecartographer='cd $HOME/robot/cartographer_ws && catkin_make_isolated --install --use-ninja'" >> ~/.bashrc
    echo "source $HOME/robot/cartographer_ws/install_isolated/setup.bash" >> ~/.bashrc
    source ~/.bashrc
  fi

  if [ ! -d "$HOME/robot/navigation_ws" ]; then
    echo "start to config navigation workspace..."
    source ~/.bashrc
    mkdir -p $HOME/robot/navigation_ws/src
    
    sudo apt install -y ros-${ROS_DISTRO}-navigation*
    sudo apt remove -y ros-${ROS_DISTRO}-navigation ros-${ROS_DISTRO}-navigation-experimental
    sudo apt install -y ros-${ROS_DISTRO}-tf2-sensor-msgs ros-${ROS_DISTRO}-cmake-modules ros-${ROS_DISTRO}-diagnostic-updater
    
    cd $HOME/robot/navigation_ws/src
    git clone https://github.com/ros-planning/navigation.git
    cd navigation
    git checkout ${ROS_DISTRO}-devel
    cd $HOME/robot/navigation_ws
    catkin_make
    echo "#for navigation" >> ~/.bashrc
    echo "source $HOME/robot/navigation_ws/devel/setup.bash" >> ~/.bashrc
    source ~/.bashrc
    cd $HOME/robot/navigation_ws/src/navigation
    git clone https://github.com/rst-tu-dortmund/teb_local_planner.git
    cd teb_local_planner
    git checkout ${ROS_DISTRO}-devel
    cd $HOME/robot/navigation_ws
    rosdep install -y teb_local_planner
    catkin_make
  fi

  if [ ! -d "$HOME/robot/sensors_ws" ]; then
    echo "start to config sensors workspace..."
    source ~/.bashrc
    mkdir -p $HOME/robot/sensors_ws/src
    cd $HOME/robot/sensors_ws
    catkin_make
    echo "#for sensor" >> ~/.bashrc
    echo "source $HOME/robot/sensors_ws/devel/setup.bash" >> ~/.bashrc
  fi

  if [ ! -d "$HOME/robot/lrobot_ws" ]; then
    echo "start to config lrobot workspace..."
    source ~/.bashrc
    mkdir -p $HOME/robot/lrobot_ws/src
    cd $HOME/robot/lrobot_ws
    catkin_make
    echo "#for lrobot" >> ~/.bashrc
    echo "source $HOME/robot/lrobot_ws/devel/setup.bash" >> ~/.bashrc
  fi
}

function config_ros {
  echo "#for ros master" >> ~/.bashrc
  echo "localip=\$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print \$2}' | awk -F"/" '{print \$1}')" >> ~/.bashrc
  echo "alias $1ros='export ROS_MASTER_URI=http://$2:11311'" >> ~/.bashrc
  echo "export ROS_HOSTNAME=\$localip" >> ~/.bashrc
}

function install_zmq {
  echo "install libzmq ..."
  cd ~/Downloads
  git clone https://github.com/zeromq/libzmq.git
  cd libzmq
  mkdir build
  cd build
  cmake ..
  sudo make install
  sudo rm -rf ~/Downloads/libzmq
  echo "libzmq has been isntalled successfully"
  echo "install cppzmq ..."
  cd ~/Downloads
  git clone https://github.com/zeromq/cppzmq.git
  cd cppzmq
  mkdir build
  cd build
  cmake ..
  sudo make install
  sudo rm -rf ~/Downloads/cppzmq
  echo "cppzmq has been isntalled successfully"
}

function config_rc_local {
  sudo sh -c "echo '
[Install]
WantedBy=multi-user.target
Alias=rc-local.service
' >> /lib/systemd/system/rc-local.service"
  sudo touch /etc/rc.local
  sudo chmod 755 /etc/rc.local
  sudo sh -c "cat > /etc/rc.local" << EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
exit 0
EOF
}

function config_git {
  echo "config git..."
  sudo apt install git git-flow bash-completion
  if [ ! -d "$HOME/Documents/Software" ]; then
    mkdir -p $HOME/Documents/Software
  fi
  echo "download git-flow-completion.bash ..."
  #wget https://raw.githubusercontent.com/bobthecow/git-flow-completion/master/git-flow-completion.bash -O $HOME/Documents/Software/git/git-flow-completion.bash
  cd $HOME/Documents/Software
  git clone git@github.com:bobthecow/git-flow-completion.git
  echo "#for git" >> ~/.bashrc
  echo "source $HOME/Documents/Software/git-flow-completion/git-flow-completion.bash" >> ~/.bashrc
  sudo sh -c "cat >> ~/.bashrc" << EOF
function git_branch {  
  branch="\`git branch 2>/dev/null | grep "^\\*" | sed -e "s/^\\*\\ //"\`"  
  if [ "\${branch}" != "" ];then  
    if [ "\${branch}" = "(no branch)" ];then  
      branch="(\`git rev-parse --short HEAD\`...)"  
    fi  
    echo " (\$branch)"  
  fi  
}  
export PS1='\u@\h \[\033[01;36m\]\W\[\033[01;32m\]\$(git_branch)\[\033[00m\] \\$ '
EOF
}

function add_local_systemd {
  echo "add local systemd"
  if [ "$(lsb_release -sc)"=="bionic" ]; then
    echo "current system is bionic"
    if [ $1 ]; then
      echo "the script file is $1"
      script_name=$(basename ${1} .sh)
      service_name="/etc/systemd/system/$script_name.service"
      
      if [ ! -f $service_name ]; then
        echo "writting $service_name"
        sudo sh -c "cat > $service_name" << EOF
[Unit]
Description=launch $1
After=network.target

[Service]
Type=forking
ExecStart=$1
TimeoutSec=0
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
      sudo systemctl daemon-reload
      sudo systemctl enable $service_name
      fi
    fi
  fi
}

[ "$1" = "-h" ] && Usage
[ $# = 0 ] && Usage

while [ -n "$1" ]
do
  case "$1" in 
  --config_ustc)      use_ustc_source $2;;
  --install_ros)      install_ros ;;
  --config_ssh)       config_ssh $2 $3 ;;
  --config_workspace) config_workspace ;;
  --config_ros)       config_ros $2 $3;;
  --install_zmq)      install_zmq;;
  --config_rc_local)  config_rc_local;;
  --config_git)       config_git;;
  --add_local_systemd)add_local_systemd $2;;
  --) shift
    break ;;
  esac
  shift
done

count=1
for param in $@
do
  echo "para $count: $param"
  count=$[ $count+1 ]
done
