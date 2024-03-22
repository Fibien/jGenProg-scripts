#!/bin/bash

#----- Paths

# Define the path variable
path2defects4j="/home/project/defects4j/framework/bin"

# Use the path variable
export PATH=$PATH:$path2defects4j

math_dependency_location="/home/project/defects4j/framework/projects/Math/lib/commons-discovery-0.5.jar"
time_dependency_location="/home/project/defects4j/framework/projects/Time/lib/joda-convert-1.2.jar"

# Experiment_location
experiment_location="/home/project/experiment/"

#----- Validate arguments to the script

if [ $# -ne 2 ]; then
    echo "Error: Project name required and number of iterations required"
    exit 1
fi

#---- Functions

# Checkout a bug at a location in tmp
checkout_bug() { #args $1 Bug_category $2 Bug_number $3 Project_name $4 Mutation_rate $5 Population_size $6 Iteration

	local location="/${experiment_location}/${3}/${6}/${4}_${5}/${1}/${2}"

    defects4j checkout -p "${1}" -v "${2}"b -w "${location}"
   
   # Move to bug folder
    cd "${location}"
	
    # Compile the bug defects4j
	defects4j compile
}

# Search for a solution with jGenProg
run_jgenprog() { #args $1 Bug_category $2 Bug_number $3 Project_name $4 Mutation_rate $5 Population_size $6 Seed $7 Iteration

	local bug_location="/${experiment_location}/${3}/${7}/${4}_${5}/${1}/${2}"
	local log_location="/${experiment_location}/${3}/logs"
	local filename="result_${4}_${5}_${1}_${2}.txt"
	local dependency_location="${bug_location}/lib/"
		
	local time_paths=" -srcjavafolder src/main/java/ \
	-srctestfolder src/test/java/ \
	-binjavafolder target/classes/ \
	-bintestfolder target/test-classes"	
		
	local math_1_to_84_paths="${time_paths}"

	local math_85_plus_paths=" -srcjavafolder src/java/ \
	-srctestfolder src/test/ \
	-binjavafolder target/classes/ \
	-bintestfolder target/test-classes/"
	
	local chart_paths=" -srcjavafolder source/ \
	-srctestfolder tests/ \
	-binjavafolder build/ \
	-bintestfolder build-tests/"
		
	local command="-cp /home/project/astor/target/astor-*-jar-with-dependencies.jar \
	    fr.inria.main.evolution.AstorMain"
	
	if [ "${1}" = "Time" ]; then
		command+="${time_paths}"
		add_time_dependency "${bug_location}"
	elif [ "${1}" = "Math" ] && [ "${2}" -lt 85 ]; then
		command+="${math_1_to_84_paths}"
		add_math_dependency "${bug_location}"
	elif [ "${1}" = "Math" ]; then
		command+="${math_85_plus_paths}"
		add_math_dependency "${bug_location}"
	elif [ "${1}" = "Chart" ]; then
		command+="${chart_paths}"
	else
		echo "Invalid category"
		exit 1
	fi
	
	command+=" -location ${bug_location} \
	-dependency ${dependency_location} \
	-mutationrate ${4} \
	-population ${5} \
	-seed ${6} \
	-stopfirst true" 
	
	java "${command}" > "${log_location}/${filename}"
}

add_math_dependency(){ # $1 bug_location

	local lib_path="${1}/lib/" 
	create_folder "${lib_path}"
	sudo cp "${math_dependency_location}" "${lib_path}" 
}

add_time_dependency(){ # $1 bug_location
	
	local lib_path="${1}/lib/" 
	create_folder "${lib_path}"
	sudo cp "${time_dependency_location}" "${lib_path}" 
}

create_folder(){ # $1 Folder location

	# Check if the folder exists adn create if not present
	if [ ! -d "${1}" ]; then
		sudo mkdir "${1}/"
	fi
}

# Extracts The results, time, and generation from the bug result textfile and save the row in a CSV file
write_result(){ # args $1 Bug_category $2 Bug_number $3 Project_name $4 Mutation_rate $5 Pop $6 Iteration
	
	local result_location="/${experiment_location}/${3}/logs/"
	local filename="result_${4}_${5}_${1}_${2}.txt"	
	
	# cut -d':' -f2- use : as delimiter, choose the substring beginning at the second field to end of line
	# grep -m 1 -o, print the first occurence, xargs removes beginning and trailing whitespaces
	local result=$(grep -m 1 -o '^End Repair Search:.*' "${result_location}${filename}" | cut -d':' -f2- | sed 's/solution//' | xargs)
	local time=$(grep -m 1 -o '^Time Total(s):.*' "${result_location}${filename}" | cut -d':' -f2- | xargs)
	local generation=""
	if [ "$result" == "Found" ]; then
		generation=$(grep -m 1 -o '^GENERATION=.*' "${result_location}${filename}" | cut -d'=' -f2- | xargs)
	else 
		generation=$(grep -m 1 -o '^NR_GENERATIONS=.*' "${result_location}${filename}" | cut -d'=' -f2- | xargs)
	fi 
	
	local status=$(grep -m 1 -o '^OUTPUT_STATUS=*' "${result_location}${filename}" | cut -d'=' -f2- | xargs)
	
	#mutation, population, category, bugg, solution (Found / Not Found), generation, time 
	#echo "${4},${5},${1},${2},${result},${generation},${time},${status}" >> "/${experiment_location}/${3}/project_result.txt"

	echo "${1},${2},${4},${5},${6},${generation},${time},${result},${status}" >> "/${experiment_location}/${3}/project_result.txt"
}

execute_bug_category(){ # args $1 Bug_category $2 Project_name $3 Mutation_rate $4 Population_size $5 Seed $6 Iteration $7 Bug_array 

	local category="${1}"
	local project_name="${2}"
	local mutation_rate="${3}"
	local population_size="${4}"
	local seed="${5}"
	local iteration="${6}"
	local -n bug_array="${7}"

	for bug in "${bug_array[@]}"
    do
        checkout_bug "${category}" "${bug}" "${project_name}" "${mutation_rate}" "${population_size}"
		run_jgenprog "${category}" "${bug}" "${project_name}" "${mutation_rate}" "${population_size}" "${seed}"
		write_result "${category}" "${bug}" "${project_name}" "${mutation_rate}" "${population_size}" "${iteration}"
    done
}

execute_math_bugs(){ # args $1 Project_name $2 Mutation_rate $3 Population_size $4 Seed $5 iteration
	#local math_bugs=(2 5 8 28 40 49 50 53 70 71 73 78 80 81 82 84 85 95)
	local math_bugs=(53)
	execute_bug_category Math "${1}" "${2}" "${3}" "${4}" math_bugs "${5}"
}

execute_time_bugs(){ # args $1 Project_name $2 Mutation_rate $3 Population_size $4 Seed $5 iteration
	local time_bugs=(4 11)
	execute_bug_category Time "${1}" "${2}" "${3}" "${4}" time_bugs "${5}"
}

execute_chart_bugs(){ # args $1 Project_name $2 Mutation_rate $3 Population_size $4 Seed $5 iteration
	local chart_bugs=(1 3 5 7 13 16 25)
	execute_bug_category Chart "${1}" "${2}" "${3}" "${4}" chart_bugs "${5}"
}

execute_bug_set(){ # $1 Project_name $2 Iteration $3 Seed

	local project_name="${1}"
	local seed="${3}"
	local iteration="${2}" #update folder structures so iteration is included

	#local mutation_rates=(0.25 0.5 0.75 1)
	#local population_size=(1 25 50 100 200 400)
	local mutation_rates=(1)
	local population_size=(1)
	
	for mutation_rate in "${mutation_rates[@]}"
	do
		for population_size in "${population_size[@]}"
		do
			execute_math_bugs  "${project_name}" "${mutation_rate}" "${population_size}" "${seed}" "${iteration}"
			#execute_time_bugs  "${project_name}" "${mutation_rate}" "${population_size}" "${seed}" "${iteration}"
			#execute_chart_bugs "${project_name}" "${mutation_rate}" "${population_size}" "${seed}" "${iteration}"
		done
	done
}

execute_iterations(){ # args $1 Project_name $2 Iterations $3 Seed
	
	local project_name="${1}"
	local result_location="/${experiment_location}/${project_name}"
	local log_location="${result_location}/logs/"
	local iterations="${2}"
	
	# Create the project and log folders
	create_folder "${result_location}"
	create_folder "${log_location}"
	
	echo "Mutation,Population,Category,BuggID,Solution,Generation,Time" >> "${result_location}/project_result.txt"
	
	# when iteration with seq 1 is the first value
	for i in $(seq ${iterations}); 
	do
		execute_bug_set() "${project_name}" i "${3}"
	done
}


main() { # args $1 Project_name $2 Iterations
	local seed=1
	create_folder "${experiment_location}"
	execute_iterations "${1}" "${2}" "${seed}" 
}

# ---- MAIN -----

main "$1" "$2" #mandatory arguments when invoking run.sh
