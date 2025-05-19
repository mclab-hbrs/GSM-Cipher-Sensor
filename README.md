
# GSM-Cipher-Sensor

SDR based Sensor to capture Cipher Mode Command (CMC) messages

Note: This is the software companion repository for our paper:

<a id="paper">***A5/1 is in the Air: Passive Detection of 2G (GSM) Ciphering Algorithms*** [forthcoming]</a>

*Authors:* Matthias Koch, Christian Nettersheim, Thorsten Horstmann, Michael Rademacher

## Overview
- [GSM-Cipher-Sensor](#gsm-cipher-sensor)
  - [Overview](#overview)
  - [Introduction](#introduction)
  - [Quickstart](#quickstart)
  - [Features](#features)
      - [Prerequisites](#prerequisites)
      - [Components](#components)
  - [Usage](#usage)
  - [Setup on Raspberry Pi](#setup-on-raspberry-pi)
    - [Getting Docker and setting up systemd-service](#getting-docker-and-setting-up-systemd-service)
    - [Installing a hardware RTC (real-time-clock) for accurate timestamps](#installing-a-hardware-rtc-real-time-clock-for-accurate-timestamps)
    - [Setting up remote monitoring](#setting-up-remote-monitoring)
    - [Preconfiguring network connections via nmcli](#preconfiguring-network-connections-via-nmcli)
    - [Miscellaneous](#miscellaneous)


## Introduction

The goal of this project is to anonymously gather data on how often either **A5/1** or **A5/3** or even **A5/4** algorithms are still used in 2G networks.
This project would not have been possible without the excellent **gr-gsm** software suite by [ptrkrysik](https://github.com/ptrkrysik/gr-gsm).
For the data collection process any SDR can be used, that is supported by `grgsm_livemon` and can receive the respective frequencies.

A cheap option is any variant of [**RTL-SDR**](https://www.rtl-sdr.com/about-rtl-sdr/),  based on DVB-T Tuner Dongles with the **RTL2832U** chipset.
These usually cover the range between around ***500 kHz*** and ***1.75 GHz***, which is sufficient for all **(E-|R-)GSM-xxx** [frequency bands](https://en.wikipedia.org/wiki/GSM_frequency_bands), but not for **DCS-1800** or **PCS-1900** frequency bands. For these you could use one of Ettus Research's **USRPs**, a **HackRF One**, **BladeRF** or **LimeSDR**, but these tend to be notably more costly with the USRPs marking the high end. There are also some newer RTL-SDRs, that are still comparatively cheap, but claim to operate in the GHz range up until ***~2.3 GHz***.  

For example, we mostly used an RTL-SDR for GSM900 - as it is one of the cheapest options and very close to "plug-and-play".

For technical details on the why and how of the collection process, please refer to our [paper](#paper).

## Quickstart

There are several ways to use the scripts in this repo manually on their own. For intended usage and setup as monitoring device on a Raspiberry Pi, see [below](#setup-on-raspberry-pi).

1. Build the Container from the **Dockerfile** yourself with 
   ```
   docker build -t gsm-monitor . 
   ```
   and run it interactively, tweak **Dockerfile** if needed. For detailed description of Docker usage, see [Usage](#usage)

2. Only use **gsm-monitor** for data collection (with appropriate frequency). Output csv files are written to 
   ```
   ${OUTPUT_DIR}/tshark_${FREQUENCY}_${LAI}_${timestamp}.csv
   ```
   with the current directory as the default. See [Prerequisites](#prerequisites) for installation of **gr-gsm** and **kalibrate-rtl**.

3. Use the **Dockerfile** and **gsm-monitor.service** to set up a monitoring device on a Raspberry Pi. This is the intended use case for this repo. See [Setup on Raspberry Pi](#setup-on-raspberry-pi) for details. 
4. For additional [setup options](#miscellaneous) on the Raspi, check out the **setup.sh** and **build.sh** scripts.

                
## Features

#### Prerequisites
You will need to install **gr-gsm** locally. Depending on your OS and available **gnuradio** version, you will need different versions of **gr-gsm**:
   * ***gnuradio-3.8.2.0*** or older: [ptrkrysik's main branch](https://github.com/ptrkrysik/gr-gsm)
   * ***gnuradio-3.9.0.0*** or higher: Try [bkerler's fork](https://github.com/bkerler/gr-gsm) or [velichkov's fork](https://github.com/bkerler/gr-gsm), which work for at least up to ***gnuradio-3.11.x.x***  

Please see project's [wiki](https://osmocom.org/projects/gr-gsm/wiki/index) for information on [installation](https://osmocom.org/projects/gr-gsm/wiki/Installation) and [usage](https://github.com/ptrkrysik/gr-gsm/wiki/Usage) of **gr-gsm**.

You will also need [kalibrate-rtl](https://github.com/steve-m/kalibrate-rtl):
   * Instructions on building and installation can be found here: [build kalibrate-rtl](https://github.com/steve-m/kalibrate-rtl?tab=readme-ov-file#how)

#### Components

* ***gsm-monitor:*** 
  * can be run without prefixed frequency, instead searches for the strongest frequency in the area via **kalibrate-rtl** or filters found frequencies for the strongest belonging to a certain provider
  * options include frequency, provider and output directory, check with:
      ```
      ./gsm-monitor --help
      Usage: ./gsm-monitor [OPTIONS]

      Monitor the GSM network for A5/1, A5/3, and A5/4 encryption usage. Write
      the output to CSV files.

      If no frequency is provided, the script will automatically find the strongest
      frequency in the area and monitor that frequency.

      Options:
      -h, --help
         Show this help message and exit
      --frequency
         Frequency to monitor (default: strongest frequency in the area)
         Cannot be used in conjunction with --provider
      --provider
         MNC of the provider to monitor (e.g. in Germany: 1 - Telekom, 2 - Vodafone, 3 - O2 ).
         If not provided, any provider will be monitored.
         Cannot be used in conjunction with --frequency
      --output-dir
         Directory to write the output files to (default: current directory)
      ```
  * depending on the flags monitors either a specific frequency, the strongest overall available frequency or the the strongest frequency specific to a chosen provider
  * this is done by getting a list of available frequencies and their respective signal strength, which is then ordered (and optionally filtered by chosen provider)
  * after a frequency is chosen in any of the above ways, the frequency is probed for its LAI (consisting of MCC, MNC, LAC and CI)
  * labels capture files with frequency, provider, start timestamp and cell info
  * does the recording with **gr-gsm** and and filtering **tshark**
  * filters for package details, here the used encryption algorithms
  * could be rewritten to use any **wireshark / tshark** filter. 
  * has a watchdog that exits the SDR monitoring and filtering if either **grgsm_livemon** and/or **tshark** fail, or if not enough packages are collected in a certain testing time span
  * intended use: together with ***gsm-monitor.service*** and ***Docker image***, so that an exit triggers restart

* ***Dockerfile:*** 
  * builds the **Docker image** on top of an **ubuntu22.04** base image and uses more recent versions of **gnuradio** as well as [bkerler's fork](https://github.com/bkerler/gr-gsm) of **gr-gsm**
  * builds **kalibrate-rtl** and adjusts *PATH* variable 
  * creates an output `/output` directory for **gsm-monitor**
  * *ENTRYPOINT* is `./gsm-monitor --output-dir /output`
  * if you would like to handle restarts and automatic start-ups with docker only, you need to set the relevant `docker run` flags for restart policies
  

* ***gsm-monitor.service***:
  * a ***systemd service*** unit file
  * enables autostart of monitoring for e.g. Raspberry Pi on startup
  * enables plug-and-play monitoring on Raspberry Pis
  * writes data to csv files at `/var/lib/gsm-monitor/output/` by default
  * handles restart after failure 
  * works together with the docker container
  * per default the script in the container is run with the flag `--provider 1`, this can be dynamically changed by editting the unit file and changing the value 
  * if you want to run the service without docker, you would need to change the relevant lines in the service unit file

## Usage

The basic usage is to run the **gsm-monitor** script with an appropriate frequency to monitor usage of different 2G encryption algorithms on this frequency over long periods of time and write each occurance to a csv file with an identifier for the used algorithm and a timestamp.

Example usage: 
   ```
   ./gsm-monitor 933.4M
   ```
for frequency *933.4 MHz* ~ *E/U/ARFCN 1016*, i.e. **gsm-monitor** follows the notational convention of **gr-gsm**.

If you wanted to customize sample rate, gain or use arfcn, **gsm-monitor** could be changed/rewritten accordingly with additional arguments (check `grgsm_livemon -h` for options)

To find the correct frequency for your use case, there are several possibilities:

1. Switching to 2G only on your phone and looking at the frequency in the network settings:
 * Android: ***Settings*** $\rightarrow$ ***Connections*** $\rightarrow$ ***Mobile networks*** $\rightarrow$ ***Choose your SIM card and switch to only 2G*** (potentially unsafe)
 * either use a network monitoring app or use **USSD** code **\#0011#*
 * if you used the USSD code, you'll find the ARFCN under ***BCCH arfcn***
 * **ARFCN** stands for [*absolute radio frequency channel number*](https://en.wikipedia.org/wiki/Absolute_radio-frequency_channel_number) and translates to a frequency in the 2G network
 * you can use a tool like [cellmapper's frequency calculator](https://www.cellmapper.net/arfcn) to translate the **ARFCN** to an actual frequency

2. Using a tool like [kalibrate-rtl](https://github.com/steve-m/kalibrate-rtl) to scan for a list of the strongest signals in your immediate area (requires SDR) 
3. Using online maps like [cellmapper](https://www.cellmapper.net/map) to find the strongest signal in your area

You can build and run a **docker container** from the ***Dockerfile***:
```
docker build -t gsm-monitor .
```
To run it interactively: 
```
/usr/bin/docker -it --rm run \
   -v /etc/timezone:/etc/timezone:ro \
   -v /etc/localtime:/etc/localtime:ro \
   -v "{YOUR_OUTPUT_DIR}:/output" \
   --device=/dev/bus/usb/001/ \
   --cap-add=NET_RAW --cap-add=NET_ADMIN --cap-drop=ALL \
   gsm-monitor [OPTIONS]
```
## Setup on Raspberry Pi

To replicate the deployment options of our paper, there are several things to take care of:
   1. [Basic configuration](#getting-docker-and-setting-up-systemd-service): Choosing an appropriate OS (e.g Rasperry Pi OS Lite), installing docker and setting up the service
   2. Offline or online deployment:
      1. [Offline deployment](#installing-a-hardware-rtc-real-time-clock-for-accurate-timestamps): install an RTC for accurate timestamps
      2. [Online deployment](#setting-up-remote-monitoring): Setup a secure remote connection, e.g. via **tailscale** and optionally preconfigure network access via `nmcli` for a plug-and-play setup   


### Getting Docker and setting up systemd-service

Clone this repo, transfer it to your Raspberry Pi and build the image there, which will take some time. Alternatively, you can do a cross-platform build for the image with `docker buildx` and transfer it to your Raspi. In case you want to set them up in quantity, it might be best to configure the basics in this section - without any personalized data like ssh keys - and then copy the SD images. Runs smoothly on Raspi4's, but has trouble running on Raspi2's.

Get docker by running: 
   ```
   curl -sSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```
To have the monitoring run automatically on start-up, have a look at the gsm-monitor.service file. This helps you to register a systemd service in the following way:

1. Unit files for systemd services are usually saved at `/etc/systemd/system/<service_name>.service` or `/lib/systemd/system/<service_name>.service`.

   So we can create a symbolic link to our custom unit file, e.g. like
   ```
   ln -s path/to/gsm-monitor/gsm-monitor.service /etc/systemd/system/gsm-monitor.service
   ```
2. Make systemd reload the configuration files of the units:
   ```
   sudo systemctl daemon-reload
   ```
3. Tell systemd to start the service automatically after boot-up:
   ```
   sudo systemctl enable gsm-monitor.service
   ```
4. For testing you can run:
   ```
   sudo systemctl start gsm-monitor.service
   sudo systemctl status gsm-monitor.service
   ```
5. Use `journalctl` to log and monitor the behaviour of your new service (possibly remove various debug flags or set your own in ***gsm-monitor*** script to not clutter the output, the `set -xv` option is commented out by default), e.g.:
   ```
   journalctl -u gsm-monitor.service
   ```
   or 
   ```
   journalctl -f -u gsm-monitor.service --since "DD:MM:YYYY hh:mm:ss"
   ```
   for continued print out of new logs and timestamps
6. Once again, note that the gsm-monitor.service is running per default with `--provider 1`. To change providers, you must edit the unit file and use `sudo systemctl daemon-reload`

### Installing a hardware RTC (real-time-clock) for accurate timestamps

Since the Raspi units may be deployed anywhere, where they can be plugged to a power source, not every scenario guarantees the availability of a network. This poses a problem as the Raspis a priori get their clock from a network connection via **ntp**.

To solve this problem and assure accurate timestamps for long-term monitoring, it is useful to install a hardware-clock RTC (real-time-clock) on the raspi like **RTC DS3231** or DS1307, PCF8523 and MCP7940N. These are hardware modules that are installed on the GPIO pins of the Raspi and need to be connected appropriately, e.g. via I2C.

We will focus on the setup of DS3231 on a RaspberryPi 4 here, since it is well supported and highly accurate. For other RTCs and Raspis many steps are similar, but depending on the version of Raspi and/or RTC additional steps might be required like configuring kernel drivers.
<div style="text-align: center;">
  <img src="https://hobbycomponents.com/1940-large_default/ds3231-rtc-module-for-raspberry-pi.jpg" alt="RTC installed on Raspi" width="400" height="300" >
</div>

1. Enable I2C: DS3231 module is connected via I2C, which is not enabled by default. To enable, you need to go to the settings:
   ```
   sudo raspi-config
   ```
   there choose ``3 Interface Options`` and then ``I4 I2C``, where you can enable ``ARM I2C Interface``. After confirming your choice, you need to power off:
   ```
   sudo shutdown now
   ```
   Alternatively, you can edit the file ``/boot/firmware/config.txt`` (might be ``/boot/config.txt`` on older raspis) and add/change the following lines and then reboot / shutdown:
   ```
   dtparam=i2c_arm=on
   dtoverlay=i2c-rtc,ds32317
   ```
2. Install the RTC unit as shown in the picture (when the raspi is shutdown)
3. After reboot, make sure the DS3231 is correctly dectected by using ``i2c-tools``:
   ```
   sudo apt install i2c-tools
   ```
   and run:
   ```
   sudo i2cdetect -y 1
   ```
   If ``UU`` is correctly displayed at position ``0x68``, it is an indication that the correct kernel driver is up and running and the module is detected correctly.
4. Take a reading from the RTC via:
   ```
   sudo hwclock -r
   ```
   compare to the actual time while still connected to the network:
   ```
   date
   ```
   and finally write the current time to the module:
   ```
   sudo hwclock -w
   ```
5. When you only want to use the RTC (e.g. no network available), disable the `systemd-timesyncd.service` and the only time source after reboot will be the RTC:
   ```
   sudo systemctl disable systemd-timesyncd.service
   ```
6. You can do a sanity check by cutting any network connection, shutting down the raspi and turning it on after some time has elapsed and checking the boot sequence via:
   ```
   sudo dmesg | grep rtc
   ```
7. Optional: Depending on your OS and Raspi generation you might need to edit ``/lib/udev/hwclock-set`` by commenting out the following lines (result shown):
   ```bash
   #  if [ -e /run/systemd/system ] ; then 
   #      exit 0
   #  fi
   ```
   as well as optionally removing `fake-hwclock` package (but this is probably not necessary). See the following discussion [[1]](https://forums.raspberrypi.com/viewtopic.php?t=256726), there's also various setup scripts at [[2]](https://github.com/Seeed-Studio/pi-hats/tree/master)

### Setting up remote monitoring

[**tailscale**](https://tailscale.com/) is a WireGuard based VPN that lets you set up monitoring for your devices securely (local machine, phone and your raspis). You can also use fully self-hosted alternatives like [headscale](https://headscale.net/stable/)
1. Open an account at tailscale.com to start adding devices via:
   ```
   curl -fsSL https://tailscale.com/install.sh | sh
   ```
   or via email link
2. Follow the instruction of the setup script, then enable ssh for your devices and check their status via:
   ```
   tailscale status
   ```
3. Connect via ssh
4. For further details (e.g configuring ACLs for your team), check out the [documentation](https://tailscale.com/kb)
5. You can now login remotely and update the provider in the `gsm-monitor.service` (e.g. run a certain time for one provider and then switch to the next one to gather data on different providers)

### Preconfiguring network connections via nmcli

When deploying new devices, you want to be able to make it as easy as possible for anyone that you hand out a monitoring station to get it up and running quickly. The Raspi can automatically connect to a new never-actually-seen-before wifi connection, when that network connection is preconfigured correctly before deployment. We will only treat the case where the OS uses `NetworkManager` as network management daemon (as in Raspberry Pi OS Lite): 
   1. System-wide connections are usually stored at `/etc/NetworkManager/system-connections/`
   2. Setup new connection with `nmcli`, e.g.: 
      ```
      sudo nmcli connection add \
         save yes \
         type wifi \
         ifname wlan0 \                # interface name
         ssid test-network \           # your network name goes here
         connection.id testconn \      # your connection identifier
         autoconnect yes \             # connect automatically
         wifi-sec.auth-alg open \      # security settings
         wifi-sec.key-mgmt wpa-psk \
         wifi-sec.psk Sup3rs3cr3t1337  # password for the connection
      ```
   3. You can further interactively edit the new connection file in the afore-mentioned folder with `nmcli connection edit` or use a file editor. The new `testconn.nmconnection` should look similar to this:
      ```
      [connection]
      id=testconn
      uuid=86d1c6fe-3302-4ac9-8f82-924d9bced9d3
      type=wifi
      interface-name=wlan0

      [wifi]
      mode=infrastructure
      ssid=test-network

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk=Sup3rs3cr3t1337

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto

      [proxy]
      ```
   4. For deployment either instruct people to setup a guest network connection with your/their predefined key material or receive the connection details to an existing   connection beforehand
   5. Finally, if available, you could also just plug in an ethernet cable and get a wired connection

### Miscellaneous

To prevent various usb connection/detection, usb-claim errors and driver conflicts for `rtl-sdr` you might want to setup at least the following:
1. Blacklist DVB drivers:
   ```
   echo "blacklist dvb_usb_rtl28xxu" | sudo tee /etc/modprobe.d/blacklist-rtl.conf
   ```
   The problem to be prevented here is, that the DVB Linux kernel driver for use in digital TV reception is loaded automatically making the **RTL-SDR** unavailable for **SDR** programs. The above command permanently blacklists the responsible interfering kernel module, preventing it from loading. You could also opt to temporarily unload the DVB driver and check if it indeed worked as intended via:
   ```
   sudo rmmod dvb_usb_rtl28xxu      # unload the respective module from the Linux kernel
   lsmod | grep dvb                 # expecting an empty output here, meaning no such kernel driver is still loaded
   ```
2. Get `/etc/udev/rules.d/10-rtl-sdr.rules` from the [Universal Radio Hacker](https://github.com/jopohl/urh/wiki/SDR-udev-rules) github repo as a text file `10-rtl-sdr.rules` and add the `udev` rules:

   ```
   cat  10-rtl-sdr.rules | sudo tee /etc/udev/rules.d/10-rtl-sdr.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```
   These rules allow non-root access (`MODE:="0666"`) to the usb interface (`SUBSYSTEMS=="usb"`) for a variety of *rtl dongles*. You can adjust these rules set to only specifiy a rule for your specific device. For example, provided you were using a `Realtek Semiconductor Corp. RTL2838 DVB-T` dongle, find out its vendor and product ID via:
   ```
   $ lsusb | grep -i rtl
   Bus 001 Device 007: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T
   ```
   The respective rule then would be:
   ```
   # RTL2832U OEM vid/pid, e.g. ezcap EzTV668 (E4000), Newsky TV28T (E4000/R820T) etc.
   SUBSYSTEMS=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", MODE:="0666"
   ```
3. We have provided you with two simple and interactive scripts: **setup.sh** and **build.sh**
   * setup.sh: installs docker, blacklists DVB driver, installs udev rules, and configures network connections.
   * build.sh: builds the docker image and registers the systemd service
