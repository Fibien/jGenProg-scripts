#!/bin/bash

#----- Validate commandline arguments to the script

if [ $# -ne 2 ]; then
    echo "Error: Project name and number of iterations arguments required"
    exit 1
fi

#----- Paths

# Define defects4j path variable
path2defects4j="/home/project/defects4j/framework/bin"

# Add defects4j path variable to path
export PATH=$PATH:$path2defects4j

math_dependency_location="/home/project/defects4j/framework/projects/Math/lib/commons-discovery-0.5.jar"
time_dependency_location="/home/project/defects4j/framework/projects/Time/lib/joda-convert-1.2.jar"

# Experiment_location
experiment_location="/home/project/experiment/"

#----- Commandline arguments

project_name="${1}"
iterations="${2}"

#---- Functions

# Checkout a bug at a location in tmp
checkout_bug() { #args $1 Bug_category $2 Bug_number $3 Mutation_rate $4 Population_size $5 Iteration

	local category="${1}"
	local bug_number="${2}"
	local mutation_rate="${3}"
	local population_size="${4}"
	local iteration="${5}"
	local location="/${project_location}/${iteration}/${mutation_rate}_${population_size}/${category}/${bug_number}"

    defects4j checkout -p "${category}" -v "${bug_number}"b -w "${location}"
   
   # Move to bug folder
    cd "${location}"
	
    # Compile the bug defects4j
	defects4j compile
}

# Search for a solution with jGenProg
run_jgenprog() { #args $1 Bug_category $2 Bug_number $3 Mutation_rate $4 Population_size $5 Iteration

	local category="${1}"
	local bug_number="${2}"
	local mutation_rate="${3}"
	local population_size="${4}"
	local iteration="${5}"

	local bug_location="/${project_location}/${iteration}/${mutation_rate}_${population_size}/${category}/${bug_number}"
	local log_location="/${project_location}/logs"
	local filename="result_${mutation_rate}_${population_size}_${category}_${bug_number}.txt"
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
	
	if [ "${category}" = "Time" ]; then
		command+="${time_paths}"
		add_time_dependency "${bug_location}"
	elif [ "${category}" = "Math" ] && [ "${bug_number}" -lt 85 ]; then
		command+="${math_1_to_84_paths}"
		add_math_dependency "${bug_location}"
	elif [ "${category}" = "Math" ]; then
		command+="${math_85_plus_paths}"
		add_math_dependency "${bug_location}"
	elif [ "${category}" = "Chart" ]; then
		command+="${chart_paths}"
	else
		echo "Invalid category"
		exit 1
	fi
	
	command+=" -location ${bug_location} \
	-dependency ${dependency_location} \
	-mutationrate ${mutation_rate} \
	-population ${population_size} \
	-seed ${seed} \
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
write_result(){ # args $1 Bug_category $2 Bug_number $3 Mutation_rate $4 Pop $5 Iteration
	
	local category="${1}"
	local bug_number="${2}"
	local mutation_rate="${3}"
	local population_size="${4}"
	local iteration="${5}"
	
	local result_location="/${project_location}/logs/"
	local filename="result_${mutation_rate}_${population_size}_${category}_${bug_number}.txt"	
	
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

	echo "${category},${bug_number},${mutation_rate},${population_size},${iteration},${generation},${time},${result},${status}" >> "/${project_location}/project_result.txt"
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
        checkout_bug "${category}" "${bug}" "${mutation_rate}" "${population_size}"
		run_jgenprog "${category}" "${bug}" "${mutation_rate}" "${population_size}"
		write_result "${category}" "${bug}" "${mutation_rate}" "${population_size}" "${iteration}"
    done
}

execute_math_bugs(){ # args $1 Mutation_rate $2 Population_size $3 iteration
	local mutation_rate="${1}"
	local population_size="${2}"
	local iteration="{3}"
	#local math_bugs=(2 5 8 28 40 49 50 53 70 71 73 78 80 81 82 84 85 95)
	local math_bugs=(53)
	execute_bug_category Math "${mutation_rate}" "${population_size}" "${Iteration}" math_bugs
}

execute_time_bugs(){ # args $1 Mutation_rate $2 Population_size $3 iteration
	local mutation_rate="${1}"
	local population_size="${2}"
	local iteration="{3}"
	local time_bugs=(4 11)
	execute_bug_category Time "${mutation_rate}" "${population_size}" "${Iteration}" time_bugs
}

execute_chart_bugs(){ # args $1 Mutation_rate $2 Population_size $3 iteration
	local mutation_rate="${1}"
	local population_size="${2}"
	local iteration="{3}"
	local chart_bugs=(1 3 5 7 13 16 25)
	execute_bug_category Chart "${mutation_rate}" "${population_size}" "${Iteration}" chart_bugs
}

execute_bug_set(){ # $1 Iteration

	local iteration="${1}"

	#local mutation_rates=(0.25 0.5 0.75 1)
	#local population_size=(1 25 50 100 200 400)
	local mutation_rates=(1)
	local population_size=(1)
	
	for mutation_rate in "${mutation_rates[@]}"
	do
		for population_size in "${population_size[@]}"
		do
			execute_math_bugs "${mutation_rate}" "${population_size}" "${iteration}"
			#execute_time_bugs "${mutation_rate}" "${population_size}" "${iteration}"
			#execute_chart_bugs "${mutation_rate}" "${population_size}" "${iteration}"
		done
	done
}

execute_iterations(){
	
	local result_location="/${experiment_location}/${project_name}"
	local log_location="${result_location}/logs/"
	
	# Create the project and log folders
	create_folder "${result_location}"
	create_folder "${log_location}"
	
	echo "Mutation,Population,Category,BuggID,Solution,Generation,Time" >> "${result_location}/project_result.txt"
	
	# when iteration with seq 1 is the first value
	for i in $(seq ${iterations}); 
	do
		execute_bug_set() i
	done
}


main() {
	seed=1
	project_location="${experiment_location}/${project_name}"
	create_folder "${experiment_location}"
	execute_iterations 
}

# ---- MAIN -----


main
