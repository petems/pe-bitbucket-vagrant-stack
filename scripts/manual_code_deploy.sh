#!/bin/bash
# GIST_URL: https://gist.github.com/natemccurdy/797fa9128b7eef1f07be
# This script can be run to manually trigger Code Manager to deploy code from your control-repo. This sort of
# thing is neccesary when, for example:
#   - You've turned on Code Manager but have not yet made an RBAC token.
#   - You want to pull down the latest version of a Puppetfile module without pushing to your GMS.
#   - Something has broken the post-receive hook on your GMS that would've triggered Code Manager.
#   - Syntax errors in your Puppetfile prevent you from retrieving those fixes to that Puppetfile.

echo "==> Running r10k manually as pe-puppet to fetch new code"
sudo -u pe-puppet bash -c '/opt/puppetlabs/puppet/bin/r10k deploy environment -c /opt/puppetlabs/server/data/code-manager/r10k.yaml -p -v debug'

deploy_result=$?
[[ $deploy_result -eq 0 ]] || { echo -e "\nR10k failed to deploy your code. Check the scroll-back for errors.\n"; exit 1; }

echo "==> Delete the code dir so file-sync can do its thing"
sudo rm -rf /etc/puppetlabs/code/*

# Determine paths to certs.
certname="$(puppet agent --configprint certname)"
certdir="$(puppet agent --configprint certdir)"

# Set variables for the curl.
cert="${certdir}/${certname}.pem"
key="$(puppet agent --configprint privatekeydir)/${certname}.pem"
cacert="${certdir}/ca.pem"

echo "==> Hitting the file-sync commit endpoint at https://$(hostname -f):8140/file-sync/v1/commit"
/opt/puppetlabs/puppet/bin/curl -v -s --request POST --header "Content-Type: application/json" --data '{"commit-all": true}' \
                                --cert "$cert" \
                                --key "$key" \
                                --cacert "$cacert" \
                                "https://$(hostname -f):8140/file-sync/v1/commit" && echo

