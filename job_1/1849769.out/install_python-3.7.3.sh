cd ~

wget https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tgz
tar -xvf Python-3.7.3.tgz
rm Python-3.7.3.tgz

wget http://www.openssl.org/source/openssl-1.1.1.tar.gz
tar -xvf openssl-1.1.1.tar.gz
rm -r openssl-1.1.1.tar.gz

mkdir software 2>/dev/null || true

cd openssl-1.1.1
rm -rf ~/software/OpenSSL 2>/dev/null || true
./config --prefix=/mnt/data/users/dm4/vol12/alexfmsu_2131/software/OpenSSL shared zlib
make && make install
cd ..
rm -rf openssl-1.1.1

echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/data/users/dm4/vol12/alexfmsu_2131/software/OpenSSL/lib" >> $HOME/.bash_profile
source $HOME/.bash_profile

cd Python-3.7.3
rm -rf ~/software/Python 2>/dev/null || true
./configure --with-openssl=/mnt/data/users/dm4/vol12/alexfmsu_2131/software/OpenSSL --enable-optimizations --with-ensurepip=install --prefix=/mnt/data/users/dm4/vol12/alexfmsu_2131/software/Python
make && make install

cd ..
rm -rf Python-3.7.3
