#/bin/bash

if [ $# -ne 1 ] ; then
  echo "Usage: $0 <SlideShare_URL>"
  exit 1
fi

URL="$1"
DIR=$(echo $URL | sed 's/.*\/\(.*\)$/\1/')
mkdir -p "$DIR"
echo "$DIR"
for IMG in $(curl -s $URL| grep jpg | grep data-full | tr -d ' ' | cut -d '"' -f2) ; do
  echo $IMG
  FILENAME=$(echo $IMG | sed 's/.*\/\(.*\.jpg\).*/\1/')
  FILENAME="$DIR/$FILENAME"
  curl -s "$IMG" > $FILENAME
done
