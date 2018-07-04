#!/bin/bash

COURSE_URL="https://www.coursera.org/learn/neural-networks-deep-learning"

OUT=$(curl -s ${COURSE_URL} | grep "window.App")
MODULES=$(echo "$OUT" | sed 's/.*"onDemandCourseMaterialModules.v1":\({.*}\)}/\1/' | sed 's/},/\n/g' | grep '"moduleIds":null' | tr ' ' '\032')
LECTURES=$(echo "$OUT" |  tr ',' '\n' | grep -A 3 -B 5 '"typeName":"lecture"' | tr ' ' '\032' | tr '\n' '\031' | sed 's/"name"/\n"name"/g' | grep -v onDemandCourseMaterialItems)
COURSE_NAME=$(echo ${COURSE_URL} | sed 's/.*\/\(.*\)/\1/')

MODULE_NO=1
for line in $MODULES ; do
  line=$(echo $line | tr '\032' ' ')
  MODULE_ID=$(echo "$line" | sed 's/.*"id":"\([^"][^"]*\)".*/\1/')
  MODULE_NAME=$(echo "$line" | sed 's/.*"name":"\([^"][^"]*\)".*/\1/')
  MODULE_DIR="WEEK ${MODULE_NO} - ${MODULE_NAME}"
  echo ${MODULE_DIR}
  mkdir -p "${MODULE_DIR}"
  LECTURE_NO=1
  for Lline in $LECTURES ; do
    Lline=$(echo $Lline | tr '\032' ' ')
    Llines=$(echo $Lline | tr '\031' '\n')
    moduleId=$(echo "$Llines" | grep '"moduleId":"' | sed 's/.*"[^"][^"]*":"\([^"][^"]*\)"/\1/')
    if [ "${MODULE_ID}" == "${moduleId}" ] ; then
      L_NAME=$(echo "$Llines" | grep '"name":"' | sed 's/.*"[^"][^"]*":"\([^"][^"]*\)"/\1/')
      L_ID=$(echo "$Llines" | grep '"id":"' | sed 's/.*"[^"][^"]*":"\([^"][^"]*\)"/\1/')
      L_SLUG=$(echo "$Llines" | grep '"slug":"' | sed 's/.*"[^"][^"]*":"\([^"][^"]*\)"}/\1/')
      LECTURE_URL="https://www.coursera.org/lecture/${COURSE_NAME}/${L_SLUG}-${L_ID}"
      VIDEO_URL=$(curl -s ${LECTURE_URL} | grep "full/720p" | sed 's/.*"\([^"][^"]*\/full\/720p\/[^"][^"]*\)".*/\1/')
      VIDEO_FILE="${LECTURE_NO}. ${L_NAME}.MP4"
      echo "  ${LECTURE_NO}. ${L_NAME} ==>> ${L_ID} ==>> ${L_SLUG}"
      echo "    ${LECTURE_URL}"
      echo "      ${VIDEO_URL}"
      echo
      wget -o download.log -O "${VIDEO_FILE}" "${VIDEO_URL}"
      mv "${VIDEO_FILE}" "${MODULE_DIR}"
      LECTURE_NO=$(expr ${LECTURE_NO} + 1)
      #exit
    fi
  done
  MODULE_NO=$(expr ${MODULE_NO} + 1)
done
