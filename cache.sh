#!/usr/bin/env bash

set -euo pipefail

function save_cache() {
    
    if [[ $(aws s3 ls s3://${S3_BUCKET}/${CACHE_KEY}/ --region $AWS_REGION | head) ]]; then
        echo "--------------------- DEBUG MESSAGE ---------------------"
        echo $(aws s3 ls s3://${S3_BUCKET}/${CACHE_KEY}/ --region $AWS_REGION | head)
        echo "---------------------------------------------------------"
        echo "Cache is already existed for key: ${CACHE_KEY}"
    else
        echo "Saving cache for key ${CACHE_KEY}"

        echo "--------------------- DEBUG MESSAGE ---------------------"
        echo current path `pwd`
        echo "---------------------------------------------------------"
        
        tmp_dir="$(mktemp -d)"
        echo "currnet path `pwd`"
        (cd $CACHE_PATH && ls -l)
        (cd $CACHE_PATH && tar czf "${tmp_dir}/archive.tgz" ./*) #> /dev/null)
        echo "currnet path `pwd`"
        size="$(ls -lh "${tmp_dir}/archive.tgz" | cut -d ' ' -f 5 )"
        
        time aws s3 cp "${tmp_dir}/archive.tgz" "s3://${S3_BUCKET}/${CACHE_KEY}/archive.tgz" --region $AWS_REGION > /dev/null
        copy_exit_code=$?
        rm -rf "${tmp_dir}"
        echo "Cache size: ${size}"

        if [[ "${copy_exit_code}" == 0 ]]; then
            echo "Cache saved successfully for key: ${CACHE_KEY}"
        fi
    fi
}

function restore_cache() {

    for key in ${RESTORE_KEYS}; do
        if [[ $(aws s3 ls s3://${S3_BUCKET}/ --region $AWS_REGION | grep $key | head) ]]; then
            echo "--------------------- DEBUG MESSAGE ---------------------"
            echo $(aws s3 ls s3://${S3_BUCKET}/ --region $AWS_REGION | grep $key | head)
            k=$(aws s3 ls s3://${S3_BUCKET}/ --region $AWS_REGION | grep $key | head -n 1 | awk '{print $2}')
            echo k is $k
            echo "---------------------------------------------------------"
            tmp_dir="$(mktemp -d)"
            mkdir -p $CACHE_PATH
            time aws s3 cp s3://${S3_BUCKET}/${k//\//}/archive.tgz $tmp_dir/archive.tgz --region $AWS_REGION > /dev/null
            tar xzf "${tmp_dir}/archive.tgz" -C $CACHE_PATH #> /dev/null
        
            echo "Restoring cache for key ${key}"
            du -sm ${CACHE_PATH}/*
            exit 0
        else
            echo "Cache with key $key not found."
        fi
    done
}

# function fix_owners() {
#     if [[ -d "$CACHE_PATH" ]]; then
#         chown -R --reference "$GITHUB_WORKSPACE" "$GITHUB_WORKSPACE/.gh-actions-terragrunt" || true
#         debug_cmd ls -la "$GITHUB_WORKSPACE/.gh-actions-terragrunt"
#     fi
# }


# Main logic
echo "--------------------- DEBUG MESSAGE ---------------------"

echo ACTION is $INPUT_CACHE_ACTION
echo CACHE_PATH is $INPUT_CACHE_PATH
echo S3_BUCKET is $INPUT_S3_BUCKET_NAME
echo CACHE_KEY is $INPUT_CACHE_KEY
echo RESTORE_KEYS is $INPUT_RESTORE_KEYS
# echo AWS_REGION is $AWS_REGION
# echo AWS_SECRET_ACCESS_KEY is $AWS_SECRET_ACCESS_KEY
# echo AWS_ACCESS_KEY_ID is $AWS_ACCESS_KEY_ID

echo "---------------------------------------------------------"
echo "Current directory"
pwd
echo "---------------------------------------------------------"

validate_inputs
echo "---------------------------------------------------------"
validate_result=$(validate_inputs)
echo validate_result is $validate_result


#### check if all necessary variables are set

if [[ -z "$INPUT_CACHE_ACTION" && -z "$INPUT_S3_BUCKET_NAME" ]]; then
    echo "::error:: Required inputs are missing: cache_action, s3_bucket_name and either cache_key (if cache_action is save) or restore_keys (if cache_action is restore) must be set."
    exit 1

fi

if [[ "$INPUT_CACHE_ACTION" != 'save' ]] && [[ "$INPUT_CACHE_ACTION" != 'restore' ]]; then
    echo "::error:: Incorrect cache_action. Must be 'save' or 'restore'."
    exit 1
fi

if [[ "$INPUT_CACHE_ACTION" == "save" && -z "$INPUT_CACHE_KEY" ]]; then
    echo "::error:: Required inputs are missing: cache_action, s3_bucket_name and either cache_key (if cache_action is save) or restore_keys (if cache_action is restore) must be set."
    exit 1
fi

if [[ "$INPUT_CACHE_ACTION" == "restore" && -z "$INPUT_RESTORE_KEYS" ]]; then
    echo "::error:: Required inputs are missing: cache_action, s3_bucket_name and either cache_key (if cache_action is save) or restore_keys (if cache_action is restore) must be set."
    exit 1
fi

if [[ ! -v AWS_ACCESS_KEY_ID || ! -v AWS_SECRET_ACCESS_KEY || ! -v AWS_REGION ]]; then
    echo "::error:: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_REGION must be set"
    exit 1
fi

### Main logic

echo "Proceed main logic"
# if [[ "$1" == 'save' ]]; then
#     CACHE_KEY=$4
#     echo "--------------------- DEBUG MESSAGE ---------------------"
#     echo ACTION is $ACTION
#     echo CACHE_PATH is $CACHE_PATH
#     echo S3_BUCKET is $S3_BUCKET
#     echo CACHE_KEY is $CACHE_KEY
#     echo "---------------------------------------------------------"
#     save_cache
# elif [[ "$1" == 'restore' ]]; then
#     RESTORE_KEYS=$(echo $4|tr ',' ' ')
#     echo "--------------------- DEBUG MESSAGE ---------------------"
#     echo ACTION is $ACTION
#     echo CACHE_PATH is $CACHE_PATH
#     echo S3_BUCKET is $S3_BUCKET
#     echo RESTORE_KEYS are $RESTORE_KEYS
#     echo "---------------------------------------------------------"
#     restore_cache


# trap fix_owners EXIT

# if [[ -v AWS_ACCESS_KEY_ID ]] && [[ -v AWS_SECRET_ACCESS_KEY ]] && [[ -v AWS_REGION ]]; then
#     if [[ -v INPUT_CACHE_ACTION ]] && [[ -v INPUT_S3_BUCKET_NAME ]]; then
#         if [[ "$INPUT_CACHE_ACTION" == 'save' ]] || [[ "$INPUT_CACHE_ACTION" == 'restore' ]]; then
#             if [[ "$INPUT_CACHE_ACTION" == 'save' && -v INPUT_CACHE_KEY ]] || [[ "$INPUT_CACHE_ACTION" == 'restore' &&  -v INPUT_RESTORE_KEYS ]]; then
        
#                 setup_environment

#             else
#                 echo "::error:: Required parameters are missing: cache_action, s3_bucket_name and either cache_key (if cache_action is save) or restore_keys (if cache_action is restore) must be set."
#                 exit 1
#             fi
#         else
#             echo "::error:: Incorrect cache_action. Must be 'save' or 'restore'."
#             exit 1
#         fi
#     else
#         echo "::error:: Required parameters are missing: cache_action, s3_bucket_name and either cache_key (if cache_action is save) or restore_keys (if cache_action is restore) must be set."
#         exit 1
#     fi
# else
#     echo "::error:: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_REGION must be set"
#     exit 1
# fi
    