PROXY="http://10.200.200.1:3128"

export http_proxy="$PROXY"
export https_proxy="$PROXY"

export no_proxy="localhost,127.0.0.1,::1"

unset PROXY
