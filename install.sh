# http://sublimerobots.com/2015/12/snort-2-9-8-x-on-ubuntu-part-2/
# https://s3.amazonaws.com/snort-org-site/production/document_files/files/000/000/069/original/Snort-IPS-Tutorial.pdf

apt update
apt install sudo vim
export EDITOR=vim
visudo
# yoyo ALL=(ALL) NOPASSWD:ALL
exit

export LIBPCAP_VERSION=1.7.4
export LIBDAQ_VERSION=2.0.6
export SNORT_VERSION=2.9.8.0
export PCRE_VERSION=10.21
# 
sudo apt -y install checkinstall curl
# sudo checkinstall -D make install
mkdir ~/snort && cd ~/snort
curl http://www.tcpdump.org/release/libpcap-${LIBPCAP_VERSION}.tar.gz | tar xz 
cd libpcap-${LIBPCAP_VERSION}
sudo apt -y install flex byacc bison libpcre3-dev libdumbnet-dev zlib1g-dev
./configure --prefix=/usr
make -j$(nproc)
sudo checkinstall -y -D --pkgname=libpcap \
  --pkgversion=${LIBPCAP_VERSION} \
  --nodoc
  make install 



cd ~/snort
curl -L https://www.snort.org/downloads/snort/daq-${LIBDAQ_VERSION}.tar.gz | tar xz 
cd daq-${LIBDAQ_VERSION}

./configure
make -j$(nproc)
sudo checkinstall -y -D --pkgname=libdaq \
  --pkgversion=${LIBDAQ_VERSION} \
  --nodoc
  make install 
 
 
cd ~/snort
curl -L https://www.snort.org/downloads/snort/snort-${SNORT_VERSION}.tar.gz | tar xz 
cd snort-${SNORT_VERSION}

./configure --enable-sourcefire
make -j$(nproc)
sudo mkdir -p /usr/local/lib/snort_dynamicengine/ \
  /usr/local/include/snort \
  /usr/local/lib/snort \
  /usr/local/lib/snort/dynamic_preproc/ \
  /usr/local/lib/snort_dynamicpreprocessor/ \
  /usr/local/lib/snort/dynamic_output/ \
  /usr/local/share/doc \
  /usr/local/share/man
  
sudo checkinstall -y -D --pkgname=snort \
  --pkgversion=${SNORT_VERSION} \
  make install 
  
  
  
# Create the Snort directories:
sudo mkdir /etc/snort
sudo mkdir /etc/snort/rules
sudo mkdir /etc/snort/rules/iplists
sudo mkdir /etc/snort/preproc_rules
sudo mkdir /usr/local/lib/snort_dynamicrules
sudo mkdir /etc/snort/so_rules
 
# Create some files that stores rules and ip lists
sudo touch /etc/snort/rules/iplists/black_list.rules
sudo touch /etc/snort/rules/iplists/white_list.rules
sudo touch /etc/snort/rules/local.rules
sudo touch /etc/snort/sid-msg.map
 
# Create our logging directories:
sudo mkdir /var/log/snort
sudo mkdir /var/log/snort/archived_logs
 
 
sudo groupadd snort
sudo useradd snort -r -s /sbin/nologin -c SNORT_IDS -g snort

# Adjust permissions:
sudo chmod -R 5775 /etc/snort
sudo chmod -R 5775 /var/log/snort
sudo chmod -R 5775 /var/log/snort/archived_logs
sudo chmod -R 5775 /etc/snort/so_rules
sudo chmod -R 5775 /usr/local/lib/snort_dynamicrules
 
# Change Ownership on folders:
sudo chown -R snort:snort /etc/snort
sudo chown -R snort:snort /var/log/snort
sudo chown -R snort:snort /usr/local/lib/snort_dynamicrules

cd ~/snort/snort-2.9.8.0/etc 
sudo cp *.conf* /etc/snort
sudo cp *.map /etc/snort
sudo cp *.dtd /etc/snort

cd ~/snort/snort-2.9.8.0/src/dynamic-preprocessors/build/usr/local/lib/snort_dynamicpreprocessor/
sudo cp * /usr/local/lib/snort_dynamicpreprocessor/


curl -L https://raw.githubusercontent.com/StamusNetworks/selks-scripts/master/Scripts/Tuning/idps-interface-tuneup_stamus |sudo tee  /etc/network/if-up.d/idps-interface-tuneup  >/dev/null


(cat <<'EOF'
auto eth1
iface eth1 inet manual
        pre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/disable_ipv6
        pre-up ifconfig $IFACE up
        post-down ifconfig $IFACE down
        post-up /etc/network/if-up.d/idps-interface-tuneup
auto eth2
iface eth2 inet manual
        pre-up ifconfig $IFACE up
        post-down ifconfig $IFACE down
        post-up /etc/network/if-up.d/idps-interface-tuneup
EOF
)| sudo tee -a /etc/network/interfaces > /dev/null

(cat <<'EOF'
[Unit]
Description=Snort NIDS Daemon
After=syslog.target network.target
 
[Service]
Type=simple
ExecStart=/usr/local/bin/snort -q -Q -u snort -g snort -c /etc/snort/snort.conf -i eth1:eth2
 
[Install]
WantedBy=multi-user.target
EOF
)| sudo tee /lib/systemd/system/snort.service > /dev/null

sudo systemctl enable snort
