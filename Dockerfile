FROM ubuntu:26.04
LABEL maintainer="t.e.vandenberg@student.utwente.nl"
LABEL description="This is a custom Docker image for the POC of the steganographic attacks on opencode"

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y curl git nano 

RUN useradd -ms /bin/bash user
USER user
WORKDIR /home/user

# Install opencode (installs to ~/.opencode/bin/opencode)
RUN curl -fsSL https://opencode.ai/install | bash

# Copy configuration files to the container
COPY --chown=user:user configuration/opencode/ /home/user/.local/share/opencode/

# copy opencode.jsonc configuration file
RUN mkdir -p /home/user/.config/opencode/
COPY --chown=user:user configuration/opencode.jsonc /home/user/.config/opencode/opencode.jsonc

# Copy entrypoint script
COPY --chown=user:user entrypoint.sh /home/user/entrypoint.sh
RUN chmod +x /home/user/entrypoint.sh

# Set entrypoint to configure API key at runtime
ENTRYPOINT ["/home/user/entrypoint.sh"]
CMD ["/bin/bash"]

