# Base Docker image
FROM ubuntu:latest

# NOTE : Comment the "export http-s_proxy ..." lines if you don't need to go through a proxy
#        If you need it, replace the {username}, {password}, {proxy} and {port} fields

### PREQUISITIES ###
# Install curl, wget and apache2 using apt-get #
RUN export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& apt-get update \
&& apt-get install -y curl \
        unzip \
        apache2
# Install mongodb using apt-get then suppress the archive #
RUN export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& apt-get update \
&& apt-get install -y mongodb \
&& rm -rf /var/lib/apt/lists/*

# Create inkScope project folder #
WORKDIR /var/www/
RUN mkdir inkscope/ \
&& export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& curl -LO "https://github.com/inkscope/inkscope/archive/master.zip" \
&& unzip master.zip \
&& mv inkscope-master/* ./inkscope/ \
&& rm -R inkscope-master/ \
&& rm master.zip
### END OF PREQUISITIES ###


### INSTALLATION OF INKSCOPEVIZ ###
# Configure apache2 #
WORKDIR /etc/apache2/
# Make sure to choose the port (default : 8080)
RUN echo "Listen 8080" >> ports.conf
# Importing inkscope configuration #
# inkScope.conf must be configured before using 'docker run'
ADD inkScope.conf sites-available/

# Activate inkscope and proxy modules #
RUN a2enmod proxy_http \
&& service apache2 restart \
&& a2ensite inkScope
###END OF INKSCOPEVIZ INSTALLATION ###


### INSTALLATION OF INKSCOPECTRL ###
# Install mod-wgsi for Apache and make sure the container has the latest version of pip # 
RUN export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& apt-get update \
&& apt-get install -y libapache2-mod-wsgi \
        python-pip \
        python-requests \
&& easy_install -U pip
# Install Python dependencies #
RUN export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& pip install simplejson \
        pymongo \
        flask
  # Create directories for configuration files #
RUN mkdir -pv /opt/inkscope/etc /opt/inkscope/bin
WORKDIR /opt/inkscope/
# Please make sure you have modified inkscope-template.conf correctly
# Here are the fields you have to change : mongoDB parameters, ceph-rest-api URL (finishing with /), radosgw parameters
RUN cp /var/www/inkscope/inkscope-template.conf etc/inkscope.conf \
&& cp /var/www/inkscope/inkscopeProbe/cephprobe.py bin/ \
&& cp /var/www/inkscope/inkscopeProbe/sysprobe.py bin/ \
&& cp /var/www/inkscope/inkscopeProbe/daemon.py bin/

# Create the admin user ("system" and all capabilities) #
# User creation fields have to match with those in inkscope-template.conf
# And the "radosgw_admin" should match the ceph config parameter rgw_admin_entry (default is admin)
RUN export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& apt-get update \
&& apt-get install -y radosgw
# Need to set monitors and ceph/radosgw confs
#&& radosgw-admin user create --uid=test --display-name="test for docker" --email=test@test.com --system --caps "usage=*; users=*; metadata=*; buckets=*" --access-key=myaccesskey --secret=mysecretkey
### END OF INKSCOPECTRL INSTALLATION ###

### INSTALLATION OF SHELLINABOX (OPTIONAL) ###
# Note : shellinabox adds a console to inkScope
WORKDIR /etc/default/
# Dowload shellinabox #
RUN export http_proxy=http://username:password@proxy:port \
&& export https_proxy=http://username:password@proxy:port \
&& apt-get update \
&& apt-get install -y shellinabox
#Modify the last line of shellinabox configuration file #
RUN cp /etc/default/shellinabox /etc/default/shellinabox.tmp \
&& head -n -1 shellinabox.tmp > shellinabox \
&& echo 'SHELLINABOX_ARGS="--no-beep -t"' >> shellinabox \
&& rm shellinabox.tmp
#Uncomment this if you need to restart the service #
#RUN service shellinabox restart

# Enable shellinabox #
# Replace {hostname} with the host where shell in a box is installed
WORKDIR /etc/apache2/sites-available/
RUN cp inkScope.conf inkScope.conf.tmp \
&& head -n -3 inkScope.conf.tmp > inkScope.conf \
&& echo '    ProxyPass /shell http://hostname:4200/' >> inkScope.conf \
&& tail -n 3 inkScope.conf.tmp >> inkScope.conf \
&& rm inkScope.conf.tmp \
&& service apache2 restart
### END OF SHELLINABOX INSTALLATION ###



WORKDIR /
