#!/usr/bin/env bash
##
# docker run -v $PWD:/app -it cloudfoundry/cflinuxfs2 /app/build_libs.sh
##
set -eo pipefail

version="0.0.2"
sandbox=/tmp/sandbox
osgeolib=$sandbox/osgeolib
pythonsp=$osgeolib/python-osgeolib

apt-get install -y libtool \
                   libffi-dev \
                   tk-dev \
                   doxygen \
                   python-dev

# create osgeolib dir and add raster libs
mkdir -p $osgeolib
cd $osgeolib
wget https://s3.amazonaws.com/boundless-cloudfoundry/cflinuxfs2/rasterlibs.tar.gz
tar -xvf rasterlibs.tar.gz && rm rasterlibs.tar.gz
export PKG_CONFIG_PATH="/tmp/sandbox/osgeolib/lib/pkgconfig":"${PKG_CONFIG_PATH}"
cd $sandbox

# compile postgresql-client
wget https://ftp.postgresql.org/pub/source/v9.6.1/postgresql-9.6.1.tar.gz
tar -xf postgresql-9.6.1.tar.gz && cd postgresql-9.6.1
sed --in-place '/fmgroids/d' src/include/Makefile
./configure --prefix=$osgeolib \
            --without-readline
make -C src/bin install
make -C src/include install
make -C src/interfaces install
cd $sandbox

# compile libkml
wget https://github.com/libkml/libkml/archive/1.3.0.tar.gz
tar -xf 1.3.0.tar.gz && cd libkml-1.3.0
cmake -DCMAKE_INSTALL_PREFIX:PATH=$osgeolib .
make install
cd $sandbox

# compile openjpeg2
wget https://github.com/uclouvain/openjpeg/archive/v2.1.2.tar.gz
tar -xf v2.1.2.tar.gz && cd openjpeg-2.1.2
cmake -DCMAKE_INSTALL_PREFIX:PATH=$osgeolib .
make install
cd $sandbox

# compile geos
wget http://download.osgeo.org/geos/geos-3.6.0.tar.bz2
tar -xf geos-3.6.0.tar.bz2 && cd geos-3.6.0
./configure --prefix=$osgeolib --enable-static=no
make && make install
cd $sandbox

# compile proj
wget http://download.osgeo.org/proj/proj-4.9.3.tar.gz
tar -xf proj-4.9.3.tar.gz && cd proj-4.9.3/
./configure --prefix=$osgeolib --enable-static=no
make install
cd $sandbox

# compile gdal
wget http://download.osgeo.org/gdal/2.1.2/gdal-2.1.2.tar.gz
tar xf gdal-2.1.2.tar.gz && cd gdal-2.1.2/
./configure --prefix=$osgeolib \
    --with-jpeg \
    --with-png=internal \
    --with-geotiff=internal \
    --with-libtiff=internal \
    --with-libz=internal \
    --with-curl \
    --with-gif=internal \
    --with-geos=$osgeolib/bin/geos-config \
    --with-expat \
    --with-threads \
    --with-ecw=$osgeolib \
    --with-mrsid=$osgeolib \
    --with-mrsid_lidar=$osgeolib \
    --with-libkml=$osgeolib \
    --with-libkml-inc=$osgeolib/include/kml \
    --with-pg=$osgeolib/bin/pg_config \
    --with-openjpeg=$osgeolib \
    --enable-static=no
make install
cd swig/python
python setup.py build
mkdir -p $pythonsp
PYTHONPATH=$pythonsp
python setup.py install --prefix=$pythonsp
cd $sandbox


# compile python-ldap
wget https://pypi.python.org/packages/56/b0/d9c47d14ad801f626ff44077548324530f384461b34e4c08a98455ca242d/python-ldap-2.4.28.tar.gz
tar xf python-ldap-2.4.28.tar.gz && cd python-ldap-2.4.28
python setup.py build
PYTHONPATH=$pythonsp
python setup.py install --prefix=$pythonsp
cd $sandbox

# cleanup large boost headers
rm -fr $osgeolib/include/boost

# tar up directory
cd /tmp/sandbox/osgeolib
tar -czf /app/osgeolib-${version}-linux-x64.tar.gz *
