#!/bin/bash
#!/bin/bash
#
# LI, Zhiqiang(lee.luoman@gmail.com)
# 2019-10-10
#
http_proxy=218.107.21.252:8080
regex_ip="(2[0-4][0-9]|25[0-5]|1[0-9][0-9]|[1-9]?[0-9])(\.(2[0-4][0-9]|25[0-5]|1[0-9][0-9]|[1-9]?[0-9])){3}"
wget https://github.com.ipaddress.com -O github.ipaddress.html
wget https://fastly.net.ipaddress.com/github.global.ssl.fastly.net -O github_fastly_net.ipaddress.html
wget https://github.com.ipaddress.com/codeload.github.com -O github_codeload.ipaddress.html

github_ip=$(echo $(cat github.ipaddress.html) | grep -Eoe "$regex_ip" | head -1)
github_fastly_net_ip=$(echo $(cat github_fastly_net.ipaddress.html) | grep -Eoe "$regex_ip" | head -1)
codeload_ip=$(echo $(cat github_codeload.ipaddress.html) | grep -Eoe "$regex_ip" | head -1)

sudo cp /etc/hosts /etc/hosts.$(date "+%Y%m%d%H%M%S").bak
echo "backup hosts to /etc/hosts.$(date "+%Y%m%d%H%M%S").bak"

echo | sudo tee -a /etc/hosts
echo "#for github speedup" | sudo tee -a /etc/hosts
echo "$github_ip github.com" | sudo tee -a /etc/hosts
echo "$github_fastly_net_ip github.global.ssl.fastly.net" | sudo tee -a /etc/hosts
echo "$codeload_ip codeload.github.com" | sudo tee -a /etc/hosts

echo "restart network..."
sudo /etc/init.d/networking restart

echo "rm tmp file..."
rm github*.html

echo
echo "enjoy~"
