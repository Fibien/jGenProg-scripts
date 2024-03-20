#!/bin/bash

#----- Paths

# Define the path variable
path2defects4j="/home/project/defects4j/framework/bin"

# Use the path variable
export PATH=$PATH:$path2defects4j

#----- Validate arguments to the script

if [ $# -ne 1 ]; then
    echo "Error: Project name required"
    exit 1
fi

#---- Functions

# Checkout a bug at a location in tmp
checkout_bug() { #args $1 Bug_category $2 Bug_number $3 Project_name $4 Mut $Pop

	local location="/tmp/${3}/${4}_${5}/${1}/${2}"

    defects4j checkout -p "${1}" -v "${2}"b -w "${location}"
    # Move to bug folder
    cd "${location}"
    # Compile the bug with maven
    sudo mvn clean compile test -DskipTests
}

# Search for a solution with jGenProg
run_jgenprog() { #args $1 Bug_category $2 Bug_number $3 Project_name $4 Mut $5 Pop $6 Seed

	local bug_location="/tmp/${3}/${4}_${5}/${1}/${2}"
	local log_location="/tmp/${3}/logs"
	local filename="result_${4}_${5}_${1}_${2}.txt"

	# Run the specific bug with jGenProg
	java -cp /home/project/astor/target/astor-*-jar-with-dependencies.jar \
    fr.inria.main.evolution.AstorMain \
    -mode jgenprog \
    -srcjavafolder /src/java/ \
    -srctestfolder /src/test/ \
    -binjavafolder /target/classes/ \
    -bintestfolder /target/test-classes/ \
    -location "${bug_location}" \
    -stopfirst true \
    -seed "${6}" \
    > "${log_location}/${filename}"

}

create_folder(){ # $1 Folder location

	# Check if the folder exists adn create if not present
	if [ ! -d "${1}" ]; then
		sudo mkdir "${1}/"
	fi

}

# Extracts The results, time, and generation from the bug result textfile and save the row in a CSV file
write_result(){ # args $1 Bug_category $2 Bug_number $3 Project_name $4 Mut $5 Pop
	
	local result_location="/tmp/${3}/logs/"
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
	
	#mutation, population, category, bugg, solution (Found / Not Found), generation, time 
	echo "${4},${5},${1},${2},${result},${generation},${time}" >> "/tmp/${3}/project_result.txt"
	
}

execute_bug_category(){ # args $1 Bug_category $2 Project_name $3 Mutation_rate $4 Population_size $5 Seed $6 bug_array 

	local category="${1}"
	local project_name="${2}"
	local mutation_rate="${3}"
	local population_size="${4}"
	local seed="${5}"
	local -n bug_array="${6}"
	local result_location="/tmp/${3}"
	local log_location="${result_location}/logs/"
	
	create_folder "${result_location}"
	create_folder "${log_location}"
	
	echo "Mutation Population Category BuggID Solution Generation Time " >> "/tmp/${3}/project_result.txt"

	for bug in "${bug_array[@]}"
    do
        checkout_bug "${category}" "${bug}" "${project_name}" "${mutation_rate}" "${population_size}"
		run_jgenprog "${category}" "${bug}" "${project_name}" "${mutation_rate}" "${population_size}" "${seed}"
		write_result "${category}" "${bug}" "${project_name}" "${mutation_rate}" "${population_size}"
		
    done
}

execute_math_bugs(){ # args $1 Project_name $2 Mutation_rate $3 Population_size $4 Seed
	#local math_bugs=(2 5 8 28 40 49 50 53 70 71 73 78 80 81 82 84 85 95)
	local math_bugs=(53)
	execute_bug_category Math "${1}" "${2}" "${3}" "${4}" math_bugs
}

execute_time_bugs(){ # args $1 Project_name $2 Mutation_rate $3 Population_size $4 Seed
	local time_bugs=(4 11)
	execute_bug_category Time "${1}" "${2}" "${3}" "${4}" time_bugs
}

execute_chart_bugs(){ # args $1 Project_name $2 Mutation_rate $3 Population_size $4 Seed
	local chart_bugs=(1 3 5 7 13 16 25)
	execute_bug_category Chart "${1}" "${2}" "${3}" "${4}" chart_bugs
}

main() { # args $1 Project_name

	local project_name="${1}"
	local mutation_rate=1 
	local population_size=1
	local seed=10
	
	execute_math_bugs  "${project_name}" "${mutation_rate}" "${population_size}" "${seed}"
	#execute_time_bugs  "${project_name}" "${mutation_rate}" "${population_size}" "${seed}"
	#execute_chart_bugs "${project_name}" "${mutation_rate}" "${population_size}" "${seed}"
	
}

# ---- MAIN -----

# set the mutation_rates and population rates
# mutation_rates=(0.25 0.5 0.75 1)
# population_rates=(1 25 50 100 200 400)

main "$1" #mandatory argument when invoking run.sh