FROM python:3.9-bullseye

WORKDIR /let.s
ADD requirements.txt .

# Install dependencies in a single layer to reduce image size
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    default-mysql-client \
    default-libmysqlclient-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install any needed packages specified in requirements.txt
RUN pip3 install --no-cache-dir --trusted-host pypi.python.org -r requirements.txt

ADD . .

RUN python3.7 setup.py build_ext --inplace

# agree to license
RUN mkdir ~/.config && touch ~/.config/ripple_license_agreed

EXPOSE 80

CMD ["python3.7", "-u", "lets.py"]