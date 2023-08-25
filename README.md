# pyv

## Description

pyv is an utility to manage python distributions and related virtualenvs

## Example

```
% pyv l
# distributions
 from_path:Python 3.6.6:/home/thomas/local/pyv/venvs/default/bin
 Python-2.7.14:Python 2.7.14:/home/thomas/local/pyv/distributions/Python-2.7.14
 Python-3.6.8:Python 3.6.8:/home/thomas/local/pyv/distributions/Python-3.6.8
 Python-3.7.0:Python 3.7.0:/home/thomas/local/pyv/distributions/Python-3.7.0
*Python-3.7.2:Python 3.7.2:/home/thomas/local/pyv/distributions/Python-3.7.2

# virtualenvs
*default:Python 3.6.8:/home/thomas/local/pyv/venvs/default
 EasyAVR:Python 3.6.8:/home/thomas/local/pyv/venvs/EasyAVR
 test:Python 3.6.8:/home/thomas/local/pyv/venvs/test
```

## Command

### pyv link

create venv ($1) symlink for the current or specified pyv venv ($2).

usage is :  pyv link [venv target name] [pyv venv name]
- venv target name, by default is *venv*
- pyv venv name, by default is the current pyv virtualenv

``` shell
% pyv l
[...]
*test:[....]
[...]
% pyv link
% ls -l
venv -> /home/thomas/local/pyv/venvs/test
% pyv link .env
% ls -l
.env -> /home/thomas/local/pyv/venvs/test
venv -> /home/thomas/local/pyv/venvs/test
```

## Special Variables

### PYV_BUILD_OPENSSL

during build process, you can force the openssl distribution to use,
by setting the PYV_BUILD_OPENSSL variable.

After a build of openssl:

``` shell
./config --prefix=/usr/local/openssl-1.1.1v --openssldir=/usr/local/openssl-1.1.1v/ssl
make
make install
```

You can use the custom openssl build with:

``` shell
PYV_BUILD_OPENSSL=/usr/local/openssl-1.1.1v pyv build 3.9.18
```
