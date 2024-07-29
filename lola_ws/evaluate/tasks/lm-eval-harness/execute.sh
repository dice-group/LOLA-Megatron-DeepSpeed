#!/bin/bash
. task.config

# export CUDA_VISIBLE_DEVICES=1
slurm=false

# # Parse the commandline args into models, sub tasks and languages
# Sample usage: bash execute.sh -m model_id -s subtask -l language -r absolute_path_result_dir -c
# Example: bash execute.sh -m dice-research/lola_v1 -s xnli -l de -r /data/kshitij/LOLA-Megatron-DeepSpeed/lola_ws/evaluate/tasks/lm-eval-harness/Results -c
# Not using the flag will give an error if model_id, subtask, language and result_path are not specified
# The 'c' is to set the slurm flag 

while getopts ":m:s:l:a:r:c" opt; do
  case $opt in
    m) model="$OPTARG"
    ;;
    s) sub_task="$OPTARG"
    ;;
    l) lang="$OPTARG"
    ;;
    a) alt_lang="$OPTARG"
    ;;
    r) result_path="$OPTARG"
    ;;
    c) slurm=true
    ;;
    \?) echo "Invalid option -$OPTARG" >&3
    exit 1
    ;;
  esac

  if [[ $opt != c && -z $OPTARG ]]; then
    echo "Option -$opt requires an argument" >&2
    exit 1
  fi
done


# Activate the virtual environment
CONDA_VENV_DIR=$(realpath ./$TASK_NAME-eval)
source activate ./$TASK_NAME-eval

# the statement below is required on slurm
if [[ "$slurm" == true ]]; then
  echo "Setting LD_LIBRARY_PATH for noctua2."
  export LD_LIBRARY_PATH=$CONDA_VENV_DIR/lib/python3.12/site-packages/nvidia/nvjitlink/lib:$LD_LIBRARY_PATH
fi


make_dir() {
	delimiter="/"
	gen_path="/"
	declare -a path_array=($(echo $1 | tr "$delimiter" " "))
	for dir in "${path_array[@]}"
	do
		gen_path="$gen_path/$dir"
		if [[ ! -d "$gen_path" ]]; then
			mkdir -p $gen_path
		fi
	done
	
}


# export this variable to your environment before running this script: export HF_LOLA_EVAL_AT=<your-access-token-here>
huggingface-cli login --token $HF_LOLA_EVAL_AT

final_task_id=""
task_dir_name=""
# check if the ID needs interpolation
if [[ "$sub_task" == *"<lang>"* ]]; then
  final_task_id="${sub_task//<lang>/$alt_lang}"
  task_dir_name="${sub_task//<lang>/$lang}"
else
  final_task_id="${sub_task}_$alt_lang"
  task_dir_name="${sub_task}_$lang"
fi


# Ensuring existence/generating results directory in results/task/model/subtask/language support

# result_path="$result_path/lm-eval-harness/$sub_task/$(cut -d'/' -f2 <<<$model)/$lang"
# path to cache the lm-eval-harness predictions
# cache_path="$result_path/lm-eval-harness/cache"
# path to save results
result_path="$result_path/lm-eval-harness/$task_dir_name/"
make_dir $result_path

lm_eval --model hf \
    --model_args pretrained="${model}" \
    --tasks $final_task_id \
    --device cuda:0 \
    --batch_size auto:4 \
    --log_samples \
    --output_path "${result_path}" \
    --trust_remote_code

