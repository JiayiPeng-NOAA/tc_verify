#!/bin/bash
export PS4=' + exglobal_det_tcgen.sh line $LINENO: '

#export cartopyDataDir=${cartopyDataDir:-${FIXtc_verify}/cartopy}
if [ ${machine} = "jet" ]; then
#  export cartopyDataDir=${cartopyDataDir:-/mnt/lfs4/HFIP/hwrfv3/local/share/cartopy}
  export cartopyDataDir=${cartopyDataDir:-/mnt/lfs4/HFIP/hwrfv3/Jiayi.Peng/cartopy}
elif [ ${machine} = "hera" ]; then
  export cartopyDataDir=${cartopyDataDir:-/scratch2/NCEPDEV/ensemble/Jiayi.Peng/noscrub/cartopy}
else
  export cartopyDataDir=${cartopyDataDir:-${FIXtc_verify}/cartopy}
fi

export savePlots=${savePlots:-YES}
export YEAR=${YYYY}
export TCGENdays="TC Genesis(05/01/${YEAR}-11/30/${YEAR})"
export basinlist="al ep wp"
export modellist="gfs ecmwf cmc"

noaa_logo() {
  TargetImageName=$1
  WaterMarkLogoFileName=${FIXtc_verify}/noaa.png
  echo "Start NOAA Logo marking... "
  SCALE=50
  composite -gravity northwest -quality 2 \( $WaterMarkLogoFileName -resize $SCALE% \) "$TargetImageName" "$TargetImageName"
  error=$?
  echo "NOAA Logo is generated. "
  return $error
}
nws_logo() {
  TargetImageName=$1
  WaterMarkLogoFileName=${FIXtc_verify}/nws.png
  echo "Start NWS Logo marking... "
  SCALE=50
  composite -gravity northeast -quality 2 \( $WaterMarkLogoFileName -resize $SCALE% \) "$TargetImageName" "$TargetImageName"
  error=$?
  echo "NWS Logo is generated. "
  return $error
}

###### basin/model do loop start ######
for basin in $basinlist; do
for model in $modellist; do

export DATAroot=${DATA}/tcgen
if [ ! -d ${DATAroot} ]; then mkdir -p ${DATAroot}; fi
export INPUT=${DATAroot}/input/${basin}_${model}
if [ ! -d ${INPUT} ]; then mkdir -p ${INPUT}; fi
export OUTPUT=${DATAroot}/output/${basin}_${model}
if [ ! -d ${OUTPUT} ]; then mkdir -p ${OUTPUT}; fi

if [ ${model} = "gfs" ]; then
  cp ${COMINgenesis}/${model}_genesis_${YEAR} ${INPUT}/ALLgenesis_${YEAR}
  export INIT_FREQ=6
elif [ ${model} = "ecmwf" ]; then
  cp ${COMINgenesis}/${model}_genesis_${YEAR} ${INPUT}/ALLgenesis_${YEAR}
  export INIT_FREQ=12
elif [ ${model} = "cmc" ]; then
  cp ${COMINgenesis}/${model}_genesis_${YEAR} ${INPUT}/ALLgenesis_${YEAR}
  export INIT_FREQ=12
fi

if [ ${basin} = "al" ]; then
  cp ${COMINadeckNHC}/aal*.dat ${INPUT}/.
  cp ${COMINbdeckNHC}/bal*.dat ${INPUT}/.  
  export BASIN_MASK="AL"
  grep "AL,  9" ${INPUT}/ALLgenesis_${YEAR} > ${INPUT}/genesis_${YEAR}
  grep "HC,"  ${INPUT}/ALLgenesis_${YEAR} >> ${INPUT}/genesis_${YEAR}
elif [ ${basin} = "ep" ]; then
  cp ${COMINadeckNHC}/aep*.dat ${INPUT}/.
  cp ${COMINbdeckNHC}/bep*.dat ${INPUT}/.
  export BASIN_MASK="EP"
  grep "EP,  9" ${INPUT}/ALLgenesis_${YEAR} > ${INPUT}/genesis_${YEAR}
  grep "HC,"  ${INPUT}/ALLgenesis_${YEAR} >> ${INPUT}/genesis_${YEAR}
elif [ ${basin} = "wp" ]; then
  cp ${COMINadeckJTWC}/awp*.dat ${INPUT}/.
  cp ${COMINbdeckJTWC}/bwp*.dat ${INPUT}/.
  export BASIN_MASK="WP"
  grep "WP,  9" ${INPUT}/ALLgenesis_${YEAR} > ${INPUT}/genesis_${YEAR}
  grep "HC,"  ${INPUT}/ALLgenesis_${YEAR} >> ${INPUT}/genesis_${YEAR}
fi

#--- run for TC_gen
cd ${OUTPUT}
cp ${PARMtc_verify}/TCGen_template.conf .
export VALID_FREQ=6

export SEARCH0="METBASE_template"
export SEARCH1="INPUT_BASE_template"
export SEARCH2="OUTPUT_BASE_template"
export SEARCH3="YEAR_template"
export SEARCH4="INIT_FREQ_template"
export SEARCH5="VALID_FREQ_template"
export SEARCH6="BASIN_MASK_template"

sed -i "s|$SEARCH0|$MetOnMachine|g" TCGen_template.conf
sed -i "s|$SEARCH1|$INPUT|g" TCGen_template.conf
sed -i "s|$SEARCH2|$OUTPUT|g" TCGen_template.conf
sed -i "s|$SEARCH3|$YEAR|g" TCGen_template.conf
sed -i "s|$SEARCH4|$INIT_FREQ|g" TCGen_template.conf
sed -i "s|$SEARCH5|$VALID_FREQ|g" TCGen_template.conf
sed -i "s|$SEARCH6|$BASIN_MASK|g" TCGen_template.conf

run_metplus.py -c ${OUTPUT}/TCGen_template.conf

#--- plot the Hits/False Alarms Distribution
#export OUTPUT=${DATAroot}/output/${basin}_${model}
cd ${OUTPUT}
cp ${USHtc_verify}/hits_${basin}.py .
grep "00    FYOY" tc_gen_${YEAR}_genmpr.txt > tc_gen_hits.txt
export hitfile="tc_gen_hits.txt"
if [ ${machine} = "jet" ]; then
  ${PYTHONonJET} hits_${basin}.py
elif [ ${machine} = "hera" ]; then
  ${PYTHONonHERA} hits_${basin}.py
else
  python hits_${basin}.py
fi

convert TC_genesis.png tcgen_hits_${basin}_${model}.gif

# Attach NOAA logo
export gif_name=tcgen_hits_${basin}_${model}.gif
TargetImageName=$gif_name
noaa_logo $TargetImageName
error=$?

# Attach NWS logo
export gif_name=tcgen_hits_${basin}_${model}.gif
TargetImageName=$gif_name
nws_logo $TargetImageName
error=$?

rm -f TC_genesis.png

cp ${USHtc_verify}/false_${basin}.py .
grep "00    FYON" tc_gen_${YEAR}_genmpr.txt > tc_gen_false.txt
grep "NA    FYON" tc_gen_${YEAR}_genmpr.txt >> tc_gen_false.txt
export falsefile="tc_gen_false.txt"
if [ ${machine} = "jet" ]; then
  ${PYTHONonJET} false_${basin}.py
elif [ ${machine} = "hera" ]; then
  ${PYTHONonHERA} false_${basin}.py
else
  python false_${basin}.py
fi

convert TC_genesis.png tcgen_falseAlarm_${basin}_${model}.gif
rm -f TC_genesis.png

# Attach NOAA logo
export gif_name1=tcgen_falseAlarm_${basin}_${model}.gif
TargetImageName=$gif_name1
noaa_logo $TargetImageName
error=$?

# Attach NWS logo
export gif_name1=tcgen_falseAlarm_${basin}_${model}.gif
TargetImageName=$gif_name1
nws_logo $TargetImageName
error=$?

cp ${USHtc_verify}/tcgen_space_${basin}.py .
if [ ${machine} = "jet" ]; then
  ${PYTHONonJET} tcgen_space_${basin}.py
elif [ ${machine} = "hera" ]; then
  ${PYTHONonHERA} tcgen_space_${basin}.py
else
  python tcgen_space_${basin}.py
fi

convert TC_genesis.png tcgen_HitFalse_${basin}_${model}.gif
rm -f TC_genesis.png

# Attach NOAA logo
export gif_name2=tcgen_HitFalse_${basin}_${model}.gif
TargetImageName=$gif_name2
noaa_logo $TargetImageName
error=$?

# Attach NWS logo
export gif_name2=tcgen_HitFalse_${basin}_${model}.gif
TargetImageName=$gif_name2
nws_logo $TargetImageName
error=$?

#export COMOUTroot=${COMOUT}/${basin}_${model}
export COMOUTroot=${COMOUT}
if [ "$SENDCOM" = 'YES' ]; then
  if [ ! -d ${COMOUTroot}/stats ]; then mkdir -p ${COMOUTroot}/stats; fi
  cp ${OUTPUT}/tc_gen_${YEAR}_ctc.txt ${COMOUTroot}/stats/tc_gen_${YEAR}_ctc_${basin}_${model}.txt
  cp ${OUTPUT}/tc_gen_${YEAR}_cts.txt ${COMOUTroot}/stats/tc_gen_${YEAR}_cts_${basin}_${model}.txt
  cp ${OUTPUT}/tc_gen_${YEAR}_genmpr.txt ${COMOUTroot}/stats/tc_gen_${YEAR}_genmpr_${basin}_${model}.txt
  cp ${OUTPUT}/tc_gen_${YEAR}.stat ${COMOUTroot}/stats/tc_gen_${YEAR}_${basin}_${model}.stat
  cp ${OUTPUT}/tc_gen_${YEAR}_pairs.nc ${COMOUTroot}/stats/tc_gen_${YEAR}_pairs_${basin}_${model}.nc
  if [ "$savePlots" = 'YES' ]; then
    if [ ! -d ${COMOUTroot}/plots ]; then mkdir -p ${COMOUTroot}/plots; fi
#    cp ${OUTPUT}/*.gif ${COMOUTroot}/.
    cp ${OUTPUT}/tcgen_hits_${basin}_${model}.gif ${COMOUTroot}/plots/evs.hurricane_global_det.hits.${basin}.${YEAR}.${model}.season.tcgen.png
    cp ${OUTPUT}/tcgen_falseAlarm_${basin}_${model}.gif ${COMOUTroot}/plots/evs.hurricane_global_det.fals.${basin}.${YEAR}.${model}.season.tcgen.png
    cp ${OUTPUT}/tcgen_HitFalse_${basin}_${model}.gif ${COMOUTroot}/plots/evs.hurricane_global_det.hitfals.${basin}.${YEAR}.${model}.season.tcgen.png
  fi   
fi

###### model do loop end ######
done

#--- plot the Performance Diagram
export DATAplot=${DATAroot}/${basin}
if [ ! -d ${DATAplot} ]; then mkdir -p ${DATAplot}; fi
cd ${DATAplot}
cp ${USHtc_verify}/tcgen_performance_diagram.py .
grep "GENESIS_DEV" ${COMOUTroot}/stats/tc_gen_${YEAR}_ctc_${basin}_gfs.txt > dev_tc_gen_${YEAR}_ctc_${basin}_gfs.txt
grep "GENESIS_DEV" ${COMOUTroot}/stats/tc_gen_${YEAR}_ctc_${basin}_ecmwf.txt > dev_tc_gen_${YEAR}_ctc_${basin}_ecmwf.txt
grep "GENESIS_DEV" ${COMOUTroot}/stats/tc_gen_${YEAR}_ctc_${basin}_cmc.txt > dev_tc_gen_${YEAR}_ctc_${basin}_cmc.txt
export CTCfile01="dev_tc_gen_${YEAR}_ctc_${basin}_gfs.txt"
export CTCfile02="dev_tc_gen_${YEAR}_ctc_${basin}_ecmwf.txt"
export CTCfile03="dev_tc_gen_${YEAR}_ctc_${basin}_cmc.txt"
#python tcgen_performance_diagram.py

if [ ${machine} = "jet" ]; then
  ${PYTHONonJET} tcgen_performance_diagram.py
elif [ ${machine} = "hera" ]; then
  export XDG_RUNTIME_DIR="/home/$USER"
  ${PYTHONonHERA} tcgen_performance_diagram.py
else
  python tcgen_performance_diagram.py
fi

convert tcgen_performance_diagram.png tcgen_performance_diagram_${basin}.gif

# Attach NOAA logo
export gif_name2=tcgen_performance_diagram_${basin}.gif
TargetImageName=$gif_name2
noaa_logo $TargetImageName
error=$?

# Attach NWS logo
export gif_name2=tcgen_performance_diagram_${basin}.gif
TargetImageName=$gif_name2
nws_logo $TargetImageName
error=$?

if [ "$SENDCOM" = 'YES' ]; then
if [ "$savePlots" = 'YES' ]; then
  if [ ! -d ${COMOUTroot}/plots ]; then mkdir -p ${COMOUTroot}/plots; fi
#  cp ${DATAplot}/*.gif ${COMOUTroot}/.
  cp ${DATAplot}/tcgen_performance_diagram_${basin}.gif ${COMOUTroot}/plots/evs.hurricane_global_det.performancediagram.${basin}.${YEAR}.season.tcgen.png
fi
fi
### basin do loop end
done

