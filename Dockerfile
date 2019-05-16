# Check http://releases.llvm.org/download.html#8.0.0 for the latest available binaries
FROM ubuntu:18.04

ENV EMCC_SDK_VERSION 1.38.29
ENV EMCC_SDK_ARCH 64
ENV EMCC_BINARYEN_VERSION 1.38.29

# Make sure the image is updated, install some prerequisites,
# Download the latest version of Clang (official binary) for Ubuntu
# Extract the archive and add Clang to the PATH
RUN apt-get update && apt-get install -y \
  xz-utils \
  build-essential \
  curl \
  libssl-dev \
  gnupg \
  ca-certificates \
  git-core \
  openjdk-8-jre-headless \
  python \
  cmake \
  nodejs \
  npm

RUN git clone https://github.com/juj/emsdk.git \
  && cd /emsdk \
  && ./emsdk update-tags \
  && ./emsdk install --build=MinSizeRel sdk-tag-$EMCC_SDK_VERSION-${EMCC_SDK_ARCH}bit \
  && mkdir -p /clang \
  && cp -r /emsdk/clang/tag-e$EMCC_SDK_VERSION/build_tag-e${EMCC_SDK_VERSION}_${EMCC_SDK_ARCH}/bin /clang \
  && mkdir -p /clang/src \
  && cp /emsdk/clang/tag-e$EMCC_SDK_VERSION/src/emscripten-version.txt /clang/src/ \
  && mkdir -p /emscripten \
  && cp -r /emsdk/emscripten/tag-$EMCC_SDK_VERSION/* /emscripten \
  && cp -r /emsdk/emscripten/tag-${EMCC_SDK_VERSION}_${EMCC_SDK_ARCH}bit_optimizer/optimizer /emscripten/ \
  && mkdir -p /binaryen \
  && cp -r /emsdk/binaryen/tag-${EMCC_BINARYEN_VERSION}_${EMCC_SDK_ARCH}bit_binaryen/* /binaryen \
  && echo "import os\nLLVM_ROOT='/clang/bin/'\nNODE_JS='nodejs'\nEMSCRIPTEN_ROOT='/emscripten'\nEMSCRIPTEN_NATIVE_OPTIMIZER='/emscripten/optimizer'\nSPIDERMONKEY_ENGINE = ''\nV8_ENGINE = ''\nTEMP_DIR = '/tmp'\nCOMPILER_ENGINE = NODE_JS\nJS_ENGINES = [NODE_JS]\nBINARYEN_ROOT = '/binaryen/'\n" > ~/.emscripten \
  && rm -rf /emsdk \
  && rm -rf /emscripten/tests \
  && rm -rf /emscripten/site \
  && rm -rf /binaryen/src /binaryen/lib /binaryen/CMakeFiles \
  && for prog in em++ em-config emar emcc emconfigure emmake emranlib emrun emscons emcmake; do \
         ln -sf /emscripten/$prog /usr/local/bin; done

RUN emcc --version
RUN mkdir -p /tmp/emscripten_test && cd /tmp/emscripten_test
RUN printf '#include <iostream>\nint main(){std::cout<<"HELLO"<<std::endl;return 0;}' > test.cpp
RUN em++ -O2 test.cpp -o test.js && nodejs test.js
RUN em++ test.cpp -o test.js && nodejs test.js
RUN em++ -s WASM=1 test.cpp -o test.js && nodejs test.js \
    && cd / \
    && rm -rf /tmp/emscripten_test \
    && echo "All done."

RUN apt-get update && apt-get install -y libssl-dev

# Set working directory
ENV APP_DIR /src/libkmip

# Setup application
RUN mkdir -p $APP_DIR
WORKDIR $APP_DIR
COPY . .

# Start from a Bash prompt
CMD [ "/bin/bash" ]
WORKDIR /



## We need at least g++-8, but stretch comes with g++-6
## Set up the Debian testing repo, and then install g++ from there...
#RUN sudo bash -c "echo \"deb http://ftp.us.debian.org/debian testing main contrib non-free\" >> /etc/apt/sources.list" \
#  && sudo apt-get update \
#  # bzip2 and libgconf-2-4 are necessary for extracting firefox and running chrome, respectively
#  && sudo apt-get install bzip2 libgconf-2-4 node-less cmake build-essential clang-format-6.0 \
#                  uglifyjs chromium ccache libncurses6 gfortran f2c \
#  && sudo apt-get install -t testing g++-8 \
#  && sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 60 --slave /usr/bin/g++ g++ /usr/bin/g++-6 \
#  && sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 80 --slave /usr/bin/g++ g++ /usr/bin/g++-8 \
#  && sudo update-alternatives --set gcc /usr/bin/gcc-8 \
#  && sudo apt-get clean \
#  && sudo apt-get autoremove \
#  && sudo ln -s /usr/bin/clang-format-6.0 /usr/bin/clang-format \
#  && sudo bash -c "echo 'application/wasm wasm' >> /etc/mime.types"
#
#RUN sudo pip install pytest pytest-xdist pytest-instafail selenium PyYAML flake8 \
#    && sudo rm -rf /root/.cache/pip
#
## Get recent version of Firefox and geckodriver
#RUN sudo wget --quiet -O firefox.tar.bz2 https://download.mozilla.org/\?product\=firefox-latest-ssl\&os\=linux64\&lang\=en-US \
#  && sudo tar jxf firefox.tar.bz2 \
#  && sudo rm -f /usr/local/bin/firefox \
#  && sudo ln -s $PWD/firefox/firefox /usr/local/bin/firefox \
#  && sudo wget --quiet https://github.com/mozilla/geckodriver/releases/download/v0.21.0/geckodriver-v0.21.0-linux64.tar.gz \
#  && sudo tar zxf geckodriver-v0.21.0-linux64.tar.gz -C /usr/local/bin \
#  && sudo rm -f firefox.tar.bz2 geckodriver-v0.21.0-linux64.tar.gz
#
## Get recent version of chromedriver
#RUN sudo wget --quiet https://chromedriver.storage.googleapis.com/2.41/chromedriver_linux64.zip \
#  && sudo unzip chromedriver_linux64.zip \
#  && sudo mv $PWD/chromedriver /usr/local/bin \
#  && sudo rm -f chromedriver_linux64.zip
#
#
## start xvfb automatically to avoid needing to express in circle.yml
#ENV DISPLAY :99
#RUN printf '#!/bin/sh\nXvfb :99 -screen 0 1280x1024x24 &\nexec "$@"\n' > /tmp/entrypoint \
#  && chmod +x /tmp/entrypoint \
#        && sudo mv /tmp/entrypoint /docker-entrypoint.sh
#
## ensure that the build agent doesn't override the entrypoint
#LABEL com.circleci.preserve-entrypoint=true
#
#ENTRYPOINT ["/docker-entrypoint.sh"]
#CMD ["/bin/sh"]
#WORKDIR /src
