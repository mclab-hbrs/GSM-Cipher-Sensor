FROM ubuntu:22.04

# Install dependencies non-interactively
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    python3 \
    python3-docutils \
    python3-scipy \
    gnuradio \
    tshark \
    # Dependencies for gr-gsm from 
    # https://osmocom.org/projects/gr-gsm/wiki/Installation#Debian-based-distributions-Debian-Testing-Ubuntu-1604-Kali-Rolling-Edition
    cmake \
    autoconf \
    libtool \
    pkg-config \
    build-essential \
    libcppunit-dev \
    swig \
    doxygen \
    liblog4cpp5-dev \
    gnuradio-dev \
    libosmocore-dev \
    gr-osmosdr \
    # Required to git clone gr-gsm
    ca-certificates \
    git \
    # Dependencies for kalibrate-rtl from https://github.com/steve-m/kalibrate-rtl
    libfftw3-dev \
    automake \
    g++ \
    librtlsdr0\
    librtlsdr-dev \
    # Required to use the host timezone in the container
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Clone gr-gsm \
RUN git clone https://github.com/bkerler/gr-gsm.git \
    && cd gr-gsm \
    && mkdir build \
    && cd build \
    && cmake .. \
    && mkdir $HOME/.grc_gnuradio/ $HOME/.gnuradio/ \
    && make \
    && make install \
    && ldconfig \
    && cd ../.. \
    && rm -rf gr-gsm

# Clone kalibrate-rtl
RUN git clone https://github.com/steve-m/kalibrate-rtl.git

# Run the build commands
RUN cd kalibrate-rtl \
    &&./bootstrap \
    && CXXFLAGS='-W -Wall -O3' ./configure \
    && make

# Add kalibrate-rtl/src to the PATH, so that the binary can be run from anywhere
# and be called by "kal <args>"
ENV PATH="/kalibrate-rtl/src:${PATH}"

# This is only relevant for rtl-sdr v4
# Required to for correct driver management https://www.rtl-sdr.com/tag/install-guide/
# RUN apt purge -y ^librtlsdr \
#     && rm -rf /usr/lib/librtlsdr* /usr/include/rtl-sdr* /usr/local/lib/librtlsdr* /usr/local/include/rtl-sdr* /usr/local/include/rtl_* /usr/local/bin/rtl_* \
#     && apt-get install libusb-1.0-0-dev \
#     && git clone https://github.com/rtlsdrblog/rtl-sdr-blog.git \
#     && cd rtl-sdr-blog/ \
#     && mkdir build \
#     && cd build \
#     && cmake ../ -DINSTALL_UDEV_RULES=ON \
#     && make \
#     && make install \
#     && cp ../rtl-sdr.rules /etc/udev/rules.d/ \
#     && ldconfig \


# Copy the gsm-monitor script to the container
COPY gsm-monitor gsm-monitor
RUN chmod +x /gsm-monitor
RUN mkdir /output

ENTRYPOINT ["/gsm-monitor", "--output-dir", "/output"]
