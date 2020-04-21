#!/bin/bash
curl -X POST http://127.0.0.1:8080/rest/tools/clearresourcebundlecache
curl -X POST http://127.0.0.1:8080/rest/tools/clearhibernatecache
curl -X POST http://127.0.0.1:8080/rest/tools/cleanjavaclasses