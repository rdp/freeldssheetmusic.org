echo 'this is if the products have stayed the same, just the non product layout has changed'
rm `find public/cache*/* | grep -v git`
ruby script/runner -e production 'p Cache.clear!;' # just in case, also clears internal html caches...
./restart.sh # probably redundant
rm -f `find public/cache*/* | grep -v git` # case anything regenerated in the meantime :)
echo 'done'
