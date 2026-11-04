# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable AS base
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

# Use the correct tag tracking Fedora 45's CoreOS stable layer
FROM ghcr.io/ublue-os/akmods:coreos-stable-45 AS akmods

# 3. Pull the specific vhba kmod built by the framework
RUN akmods-install vhba

# 4. Return to your base image and copy the built, signed vhba driver into place
FROM base
COPY --from=akmods /rpms /tmp/akmods-rpms
RUN dnf5 install -y /tmp/akmods-rpms/kmod-vhba-*.rpm

# 5. Bring in your custom files and run your build.sh script
COPY system_files /
COPY build_files/build.sh /tmp/build.sh
RUN /tmp/build.sh

# 6. Ensure the final image is cryptographically signed for Secure Boot
RUN usr/bin/signing

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
