#!/bin/bash 

# Copyright 2017 Wei-Ning Hsu
# Apache 2.0 

# prepare dataset config for VAE/FHVAE training
# assume having kaldi/egs/aurora4/s5/data ready

stage=0
nj=40

AURORA4_KALDI_EGS=
egs_dir=$(pwd)/data

required="train_si84_clean train_si84_multi dev_0330 test_eval92"
vae_tr="dev_0330"
vae_tt="test_eval92"

fs=16000
fn=400
sn=160
fft=400

seg_len=20
seg_shift=20
seg_rand=True

dataset_name=dataset.cfg

. ./path.sh 
. parse_options.sh || exit 1;

if [ $# -ne 0 ]; then
    echo "Usage: $0: [options]"
    exit 1;
fi

set -eu

dataset_cfg=$egs_dir/spec_scp/${vae_tr}_tr90/$dataset_name

if [ $stage -le 0 ]; then 
    echo "$0: stage 0, check and make spec features"
    for d in $required; do
        steps/make_spec.sh $AURORA4_KALDI_EGS/data/$d \
            $egs_dir/wav/$d $egs_dir/spec_scp/$d || exit 1;
    done
fi

if [ $stage -le 1 ]; then
    echo "$0: stage 1, split $vae_tr for train/valid sets"
    steps/subset_data_dir_tr_cv_by_utt.sh \
        $AURORA4_KALDI_EGS $egs_dir/spec_scp/$vae_tr || exit 1;
fi

required="$required ${vae_tr}_tr90 ${vae_tr}_cv10"

if [ $stage -le 2 ]; then
    echo "$0: stage 2, prepare utt2uttid and utt2spkid"
    for d in $required; do
        steps/make_utt2labels.sh --isutt true \
            $egs_dir/spec_scp/$d/feats.scp \
            $egs_dir/spec_scp/$d/utt2uttid || exit 1;
        steps/make_utt2labels.sh --isutt false \
            $egs_dir/spec_scp/$d/utt2spk $egs_dir/spec_scp/$d/utt2spkid \
            $egs_dir/spec_scp/$d/spk2spkid || exit 1;
    done
fi

if [ $stage -le 3 ]; then
    echo "$0: stage 3, generate dataset.cfg"
    steps/make_dataset_conf.sh --hasspk true --hasstft true --egs aurora4 \
        --fs $fs --fn $fn --sn $sn --fft $fft --feat_type spec \
        --n_chan 2 --use_chan 0 --remove_0th True --decom mp \
        --seg_len $seg_len --seg_shift $seg_shift --seg_rand $seg_rand \
        $egs_dir/spec_scp/${vae_tr}_tr90 $egs_dir/spec_scp/${vae_tr}_cv10 \
        $egs_dir/spec_scp/${vae_tt} $dataset_cfg || exit 1;
fi
