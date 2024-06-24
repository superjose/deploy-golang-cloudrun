while [[ $# -gt 0 ]]; do
    case "$1" in
        --project_name)
            project_name="$2"
            shift 2
            ;;
        --project_description)
            project_description="$2"
            shift 2
            ;;
        --pulumi_dir)
            pulumi_dir="$2"
            shift 2
            ;;
        --project_language)
            project_language="$2"
            shift 2
            ;;
        --original_dir)
            original_dir="$2"
            shift 2
            ;;
        --project_stack)
            project_stack="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

pulumi_create() {
    # echo "Creating pulumi project - $project_name"
    # pulumi new "$project_language" --name "$project_name" --description "$project_description" --dir "$pulumi_dir" --stack "$project_stack" --non-interactive --yes
    echo "Creating pulumi project - $project_name"
/usr/bin/expect <<EOD
    spawn pulumi new "$project_language" --name "$project_name" --description "$project_description" --dir "$pulumi_dir" --stack "$project_stack" --non-interactive --yes
     expect {
        -re {A project with the name .*} {
            # Send the Enter key to proceed, assuming the default selection is acceptable
            send "\r"
            exp_continue
            # After handling the initial prompt, continue to expect the specific error about the stack
            expect {
                -re {error: stack .* already exists} {
                    puts "it ran x1!"
                    # If the error about the stack existing is found, exit with status 2
                    exit 2
                }
                timeout {
                    puts "it ran x2!"
                    # If a timeout occurs after sending Enter, exit with status 3
                    exit 3
                }
            }
        }
        timeout {
            # Handle initial timeout by exiting with a distinct status code
            exit 3
        }
         eof {
            # Check if spawn failed
        }
    }
      # Wait for the command to complete and catch its exit status
    catch wait result
    set exit_status [lindex \$result 3]

    if {\$exit_status == 255} {
        exit 2  
    }

    # Exit with the captured exit status from Pulumi command
    exit \$exit_status
EOD
    return $?
}



# Check for Pulumi CLI
if command -v pulumi > /dev/null 2>&1; then
    echo "Pulumi CLI is installed."
else
    # Download the Pulumi install script
    curl -fsSL https://get.pulumi.com | sh

    # Add Pulumi to PATH
    export PATH=$PATH:$HOME/.pulumi/bin
fi



if [ -f "$pulumi_dir/Pulumi.yaml" ] || [ -f "$pulumi_dir/Pulumi.yml" ]; then
    echo "Pulumi project exists."
else
    # Run the function and capture output
    # output=$(pulumi_create 2>&1)
    pulumi_create
    exit_status=$?
    if [ $exit_status -eq 2 ]; then
        echo "Don't worry about the error above. It's just a warning that the project already exists."
        cd "$pulumi_dir" 
        # Install go packages, assuming go.mod file is present in the directory
        go mod tidy
        cd "$original_dir"
        echo "Pulumi project was created successfully"
    elif [ $exit_status -eq 3 ]; then
        echo "Error: The command timed out."
    elif [ $exit_status -eq 0 ]; then
        echo "Pulumi project was created successfully."
    else
        echo "An error occurred with exit code: $exit_status"
    fi

fi

echo "Project stack - $project_stack"
cd "$pulumi_dir" 
pulumi stack select "$project_stack" -c
cd "$original_dir"