echo "snapshotting (production) DB..."
echo "not cleaning sessions..."
#echo "this does a sessions and half cache clear..."
#./sessions_clear.sh
#./cache_clear.sh
# partial [non file] clear here ... in case otherwise it brings down prod too hard [though prod theoretically recovers OK'ish better more now]
echo "clearing cache table(s) [only, partial cache clear]"
nice ruby script/runner -e production "p Cache.clear!" 
#rm log/* # we don't zip files anymore FWIW, so don't need to remot these...
A=`date`
B=`echo $A | tr -d \\n`
# allow this to lock the tables since it 3s total anyway...
cat ./config/database.yml
nice mysqldump -uprod_flds prod_flds_database -p > "snap$B.sql" &&  gzip "snap$B.sql" && echo "created snap$B.sql" 
echo "not snapping pub files..."
