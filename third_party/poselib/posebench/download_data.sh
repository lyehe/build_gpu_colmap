#!/bin/sh

mkdir data
cd data
mkdir relative
cd relative

# SfM fisheye image pairs from Terekhov and Larsson (ICCV'23)
wget -N http://vision.maths.lth.se/viktor/posebench/relative/fisheye_grossmunster_4342.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/fisheye_kirchenge_2731.h5

# Image pairs from IMC 2021
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_lincoln_memorial_statue.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_piazza_san_marco.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_london_bridge.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_sagrada_familia.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_british_museum.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_milan_cathedral.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_st_pauls_cathedral.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_florence_cathedral_side.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/imc_mount_rushmore.h5

# Image pairs from ScanNet. Evaluation protocol from SuperGlue paper (Sarlin et al.)
wget -N http://vision.maths.lth.se/viktor/posebench/relative/scannet1500_spsg.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/scannet1500_sift.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/scannet1500_roma.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/scannet1500_dkm.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/scannet1500_aspanformer.h5

# Image pairs from MegaDepth
wget -N http://vision.maths.lth.se/viktor/posebench/relative/megadepth1500_sift.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/megadepth1500_spsg.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/megadepth1500_splg.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/megadepth1500_roma.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/megadepth1500_dkm.h5
wget -N http://vision.maths.lth.se/viktor/posebench/relative/megadepth1500_aspanformer.h5

cd ..
mkdir absolute
cd absolute

# Queries from 7 Scenes dataset including triangulated lines from LIMAP. (SP&SG + SOLD2 + LSD)
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/7scenes_heads.h5
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/7scenes_stairs.h5

# Queries from Cambridge Landmark (SP&SG + SOLD2 + LSD)
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/cambridge_landmarks_KingsCollege.h5
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/cambridge_landmarks_StMarysChurch.h5
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/cambridge_landmarks_OldHospital.h5
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/cambridge_landmarks_GreatCourt.h5
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/cambridge_landmarks_ShopFacade.h5
wget -N http://vision.maths.lth.se/viktor/posebench/absolute/eth3d_130_dusmanu.h5

cd ..
mkdir homography
cd homography
# Homography dataset (validation set) from Barath et al. (CVPR 2023?)
wget -N http://vision.maths.lth.se/viktor/posebench/homography/barath_Alamo.h5
wget -N http://vision.maths.lth.se/viktor/posebench/homography/barath_NYC_Library.h5

cd ../..


