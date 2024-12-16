pwd
ls -l
# 获取 fetch 的仓库地址
remote_url=$(git remote -v | grep '(fetch)' | awk '{print $2}')

# 去除 .git、ssh@、https://、http://
cleaned_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')

# 将清理后的结果赋值给变量
echo "Cleaned URL: $cleaned_url"
wget http://mirrors.myhuaweicloud.com/repo/mirrors_source.sh && bash mirrors_source.sh

yum clean all
yum makecache
yum repolist
wget https://github.com/Cisco-Talos/clamav/releases/download/clamav-1.4.1/clamav-1.4.1.linux.x86_64.rpm
rpm -ivh clamav-1.4.1.linux.x86_64.rpm

# 关闭脚本中的自动退出机制 (set +e)
set +e
ls -l

which freshclam
which clamscan


clamconf -g freshclam.conf >/usr/local/etc/freshclam.conf
clamconf -g clamd.conf > /usr/local/etc/clamd.conf
clamconf -g clamav-milter.conf > /usr/local/etc/clamav-milter.conf
echo "删除 'Example' 行..."
sudo sed -i '/^Example/d' /usr/local/etc/freshclam.conf
echo "取消注释 'DatabaseMirror' 行..."
sudo sed -i 's/^#DatabaseMirror database.clamav.net/DatabaseMirror database.clamav.net/' /usr/local/etc/freshclam.conf
echo "修改 'DatabaseOwner' 为 'root'..."
sudo sed -i 's/^#DatabaseOwner clamav/DatabaseOwner root/' /usr/local/etc/freshclam.conf
cat /usr/local/etc/freshclam.conf
freshclam
/usr/local/bin/clamscan my_image.tar

clamscan -r ./
