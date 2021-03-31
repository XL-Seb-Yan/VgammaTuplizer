#!/bin/bash

input="file.txt"
while IFS= read -r line
do
  #xrdfs root://cmseos.fnal.gov/  rm  /store/user/xuyan/PrivateNtuple/${line}
  xrdcp -p root://cmseos.fnal.gov//store/user/xuyan/PrivateNtuple/${line} ./${line}
done < "$input"