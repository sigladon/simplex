using Printf

# --- 1. Definición de la Estructura de Datos ---

"""
Estructura mutable para almacenar el estado del problema Simplex.
"""
mutable struct SimplexProblem
    num_variables::Union{Int, Nothing}
    objective_type::Union{Symbol, Nothing}  # :maximize o :minimize
    objective_coeffs::Vector{Float64}
    constraints::Vector{Tuple{Vector{Float64}, Symbol, Float64}} # (coeficientes, :<=, :>=, ó :=, rhs)

    # Constructor para un problema vacío
    function SimplexProblem()
        new(nothing, nothing, [], [])
    end
end

# --- 2. Funciones de Ayuda (Helpers) ---

"""
Limpia la consola (de forma simple).
"""
function clear_screen()
    print("\033[2J\033[H")
end

"""
Muestra un resumen del estado actual del problema.
"""
function display_problem_summary(problem::SimplexProblem)
    println("=" ^ 40)
    println("      ESTADO ACTUAL DEL PROBLEMA SIMPLEX")
    println("-" ^ 40)

    # Variables
    if isnothing(problem.num_variables)
        println("1. Variables de Decisión: [No definidas]")
    else
        println("1. Variables de Decisión: $(problem.num_variables)")
    end

    # Función Objetivo
    if isnothing(problem.objective_type)
        println("2. Función Objetivo:      [No definida]")
    else
        obj_str = join(problem.objective_coeffs, ", ")
        tipo = problem.objective_type == :maximize ? "Maximizar" : "Minimizar"
        println("2. Función Objetivo:      $tipo Z = $obj_str")
    end

    # Restricciones
    println("3. Restricciones:         [$(length(problem.constraints)) definida(s)]")
    if !isempty(problem.constraints)
        for (i, (coeffs, type, rhs)) in enumerate(problem.constraints)
            coeffs_str = join(coeffs, ", ")
            @printf "   %2d: (%s) %s %.2f\n" i coeffs_str type rhs
        end
    end
    println("=" ^ 40)
end

"""
Lee y valida un vector de coeficientes del usuario.
"""
function read_coeffs(num_vars::Int)
    print("Ingrese los $(num_vars) coeficientes separados por espacio: ")
    input = split(readline())
    
    if length(input) != num_vars
        println("Error: Se esperaban $num_vars coeficientes, pero se ingresaron $(length(input)).")
        return nothing
    end
    
    try
        return parse.(Float64, input)
    catch e
        println("Error: Ingrese solo números. ($e)")
        return nothing
    end
end

"""
Lee y valida el tipo de restricción.
"""
function read_constraint_type()
    while true
        print("Tipo de restricción [1: <=, 2: >=, 3: =]: ")
        input = readline()
        if input == "1"
            return :<=
        elseif input == "2"
            return :>=
        elseif input == "3"
            return Symbol("==")
        else
            println("Opción no válida. Intente de nuevo.")
        end
    end
end

# --- 3. Submenús de Gestión ---

"""
Maneja el submenú para el Número de Variables.
"""
function handle_variables(problem::SimplexProblem)
    clear_screen()
    println("--- 1. Gestión de Variables de Decisión ---")
    if !isnothing(problem.num_variables)
        println("Valor actual: $(problem.num_variables)")
        println("\n1. Modificar número de variables")
        println("2. Eliminar (reiniciar problema)")
        println("3. Volver")
    else
        println("Valor actual: [No definido]")
        println("\n1. Ingresar número de variables")
        println("2. Volver")
    end
    print("Seleccione una opción: ")
    
    choice = readline()
    
    if isnothing(problem.num_variables) # Caso: No hay variables
        if choice == "1"
            print("Ingrese el número de variables: ")
            try
                num = parse(Int, readline())
                if num > 0
                    problem.num_variables = num
                    println("Número de variables establecido en $num.")
                else
                    println("Error: El número debe ser positivo.")
                end
            catch
                println("Error: Entrada no válida.")
            end
        elseif choice == "2"
            return
        else
            println("Opción no válida.")
        end
    else # Caso: Ya existen variables
        if choice == "1" # Modificar
            print("Ingrese el NUEVO número de variables: ")
            try
                num = parse(Int, readline())
                if num > 0
                    if num != problem.num_variables
                        println("¡ADVERTENCIA! Al cambiar el número de variables,")
                        println("la función objetivo y las restricciones serán eliminadas.")
                        print("¿Continuar? (s/n): ")
                        if lowercase(readline()) == "s"
                            problem.num_variables = num
                            # Reiniciar el resto del problema
                            problem.objective_type = nothing
                            empty!(problem.objective_coeffs)
                            empty!(problem.constraints)
                            println("Número de variables modificado a $num. Problema reiniciado.")
                        else
                            println("Modificación cancelada.")
                        end
                    else
                         println("El número de variables es el mismo.")
                    end
                else
                    println("Error: El número debe ser positivo.")
                end
            catch
                println("Error: Entrada no válida.")
            end
        elseif choice == "2" # Eliminar
            print("¿Está seguro de que desea eliminar todo el problema? (s/n): ")
            if lowercase(readline()) == "s"
                problem.num_variables = nothing
                problem.objective_type = nothing
                empty!(problem.objective_coeffs)
                empty!(problem.constraints)
                println("Problema reiniciado.")
            end
        elseif choice == "3"
            return
        else
            println("Opción no válida.")
        end
    end
    
    !isnothing(problem.num_variables) && handle_variables(problem)
end

"""
Maneja el submenú para la Función Objetivo (F.O.).
"""
function handle_objective(problem::SimplexProblem)
    # --- Validación de dependencia ---
    if isnothing(problem.num_variables)
        println("\nError: Debe definir el número de variables (Opción 1) primero.")
        print("Presione Enter para continuar...")
        readline()
        return
    end

    clear_screen()
    println("--- 2. Gestión de la Función Objetivo ---")
    
    if isnothing(problem.objective_type)
        println("Estado: [No definida]")
        println("\n1. Ingresar F.O.")
        println("2. Volver")
    else
        tipo = problem.objective_type == :maximize ? "Maximizar" : "Minimizar"
        println("Estado: $tipo Z = $(problem.objective_coeffs)")
        println("\n1. Modificar F.O.")
        println("2. Eliminar F.O.")
        println("3. Volver")
    end
    print("Seleccione una opción: ")
    choice = readline()

    if isnothing(problem.objective_type) # Caso: No hay F.O.
        if choice == "1" # Ingresar
            print("Tipo de F.O. [1: Maximizar, 2: Minimizar]: ")
            type_choice = readline()
            if type_choice == "1"
                problem.objective_type = :maximize
            elseif type_choice == "2"
                problem.objective_type = :minimize
            else
                println("Opción no válida.")
                handle_objective(problem) # Reiniciar submenú
                return
            end
            
            coeffs = read_coeffs(problem.num_variables)
            if !isnothing(coeffs)
                problem.objective_coeffs = coeffs
                println("Función Objetivo ingresada.")
            end
            
        elseif choice == "2"
            return
        else
            println("Opción no válida.")
        end
    else # Caso: Ya existe F.O.
        if choice == "1" # Modificar
            print("Tipo de F.O. [1: Maximizar, 2: Minimizar]: ")
            type_choice = readline()
            if type_choice == "1"
                problem.objective_type = :maximize
            elseif type_choice == "2"
                problem.objective_type = :minimize
            else
                println("Opción no válida.")
                handle_objective(problem) # Reiniciar submenú
                return
            end
            
            coeffs = read_coeffs(problem.num_variables)
            if !isnothing(coeffs)
                problem.objective_coeffs = coeffs
                println("Función Objetivo modificada.")
            end

        elseif choice == "2" # Eliminar
            problem.objective_type = nothing
            empty!(problem.objective_coeffs)
            println("Función Objetivo eliminada.")
            
        elseif choice == "3"
            return
        else
            println("Opción no válida.")
        end
    end
    
    handle_objective(problem) # Permanecer en el submenú
end

"""
Maneja el submenú para las Restricciones.
"""
function handle_constraints(problem::SimplexProblem)
    # --- Validación de dependencia ---
    if isnothing(problem.num_variables)
        println("\nError: Debe definir el número de variables (Opción 1) primero.")
        print("Presione Enter para continuar...")
        readline()
        return
    end

    clear_screen()
    println("--- 3. Gestión de Restricciones ---")
    if isempty(problem.constraints)
        println("No hay restricciones definidas.")
    else
        println("Restricciones actuales:")
        for (i, (coeffs, type, rhs)) in enumerate(problem.constraints)
            @printf "%2d: %s %s %.2f\n" i coeffs type rhs
        end
    end

    println("\nSubmenú de Restricciones:")
    println("1. Añadir (Ingresar) nueva restricción")
    println("2. Modificar una restricción")
    println("3. Eliminar una restricción")
    println("4. Eliminar TODAS las restricciones")
    println("5. Volver")
    print("Seleccione una opción: ")
    choice = readline()

    if choice == "1" # Añadir
        println("\nAñadiendo nueva restricción:")
        coeffs = read_coeffs(problem.num_variables)
        if !isnothing(coeffs)
            type = read_constraint_type()
            print("Ingrese el valor del lado derecho (RHS): ")
            try
                rhs = parse(Float64, readline())
                println(rhs)
                push!(problem.constraints, (coeffs, type, rhs))
                println("Restricción añadida.")
            catch
                println("Error: RHS debe ser un número.")
            end
        end

    elseif choice == "2" # Modificar
        if isempty(problem.constraints)
            println("No hay restricciones para modificar.")
        else
            print("Ingrese el número de la restricción a modificar (1-$(length(problem.constraints))): ")
            try
                idx = parse(Int, readline())
                if 1 <= idx <= length(problem.constraints)
                    println("Ingresando nueva información para la restricción $idx:")
                    coeffs = read_coeffs(problem.num_variables)
                    if !isnothing(coeffs)
                        type = read_constraint_type()
                        print("Ingrese el nuevo valor del lado derecho (RHS): ")
                        rhs = parse(Float64, readline())
                        
                        problem.constraints[idx] = (coeffs, type, rhs)
                        println("Restricción $idx modificada.")
                    end
                else
                    println("Índice fuera de rango.")
                end
            catch
                println("Entrada no válida.")
            end
        end

    elseif choice == "3" # Eliminar
        if isempty(problem.constraints)
            println("No hay restricciones para eliminar.")
        else
            print("Ingrese el número de la restricción a eliminar (1-$(length(problem.constraints))): ")
            try
                idx = parse(Int, readline())
                if 1 <= idx <= length(problem.constraints)
                    deleted = popat!(problem.constraints, idx)
                    println("Restricción $idx eliminada: $deleted")
                else
                    println("Índice fuera de rango.")
                end
            catch
                println("Entrada no válida.")
            end
        end

    elseif choice == "4" # Eliminar Todas
        if !isempty(problem.constraints)
            print("¿Está seguro de eliminar TODAS las $(length(problem.constraints)) restricciones? (s/n): ")
            if lowercase(readline()) == "s"
                empty!(problem.constraints)
                println("Todas las restricciones han sido eliminadas.")
            else
                println("Operación cancelada.")
            end
        else
            println("No hay restricciones para eliminar.")
        end

    elseif choice == "5" # Volver
        return
    else
        println("Opción no válida.")
    end
    
    print("\nPresione Enter para continuar en el submenú de restricciones...")
    readline()
    handle_constraints(problem) # Permanecer en el submenú
end

# --- 4. Funciones del Método Simplex ---

"""
Convierte el problema en forma estándar (solo restricciones <=, con variables de holgura).
Devuelve una matriz aumentada lista para el tableau inicial.
"""
function build_simplex_table(problem::SimplexProblem)
    if isnothing(problem.num_variables) || isnothing(problem.objective_type) || isempty(problem.constraints)
        error("El problema no está completamente definido.")
    end

    num_vars = problem.num_variables
    num_cons = length(problem.constraints)

    # Construcción de matriz de coeficientes
    A = zeros(Float64, num_cons, num_vars)
    b = zeros(Float64, num_cons)
    types = Symbol[]

    for (i, (coeffs, type, rhs)) in enumerate(problem.constraints)
        A[i, :] .= coeffs
        b[i] = rhs
        push!(types, type)
    end

    # Convertir restricciones a forma estándar con variables de holgura
    slack_count = sum(t == :<= for t in types)
    tableau = zeros(Float64, num_cons + 1, num_vars + slack_count + 1)

    # Insertar coeficientes de restricciones
    slack_col = 1
    for i in 1:num_cons
        tableau[i, 1:num_vars] = A[i, :]
        if types[i] == :<=
            tableau[i, num_vars + slack_col] = 1.0
            slack_col += 1
        end
        tableau[i, end] = b[i]
    end

    # Fila de la función objetivo
    z_sign = problem.objective_type == :maximize ? -1.0 : 1.0
    tableau[end, 1:num_vars] = z_sign .* problem.objective_coeffs

    return tableau
end

"""
Aplica el algoritmo del método Simplex a un tableau.
Devuelve: (tabla final, valor óptimo, valores de variables, número de iteraciones)
"""
function simplex_solve(tableau::Matrix{Float64})
    max_iter = 100
    m, n = size(tableau)
    iter = 0

    while true
        iter += 1
        if iter > max_iter
            println("Se alcanzó el número máximo de iteraciones ($max_iter).")
            break
        end

        # 1. Verificar si la solución es óptima (no hay coeficientes negativos en la fila Z)
        z_row = tableau[end, 1:n-1]
        if all(z_row .>= -1e-8)
            println("\nSolución óptima encontrada en $iter iteraciones.")
            break
        end

        # 2. Columna pivote (menor valor en Z)
        pivot_col = argmin(z_row)

        # 3. Fila pivote (mínimo cociente positivo)
        ratios = [tableau[i, end] / tableau[i, pivot_col] for i in 1:m-1 if tableau[i, pivot_col] > 0]
        if isempty(ratios)
            println("Problema no acotado.")
            break
        end

        pivot_row = argmin([tableau[i, end] / tableau[i, pivot_col] > 0 ? tableau[i, end] / tableau[i, pivot_col] : Inf for i in 1:m-1])

        # 4. Normalizar fila pivote
        pivot_val = tableau[pivot_row, pivot_col]
        tableau[pivot_row, :] ./= pivot_val

        # 5. Eliminar columna pivote de otras filas
        for i in 1:m
            if i != pivot_row
                factor = tableau[i, pivot_col]
                tableau[i, :] .-= factor .* tableau[pivot_row, :]
            end
        end
    end

    # Calcular valores de las variables básicas
    num_vars = n - m  # número aproximado de variables originales + holgura
    variable_values = zeros(Float64, n - 1)
    for j in 1:n-1
        col = tableau[1:end-1, j]
        if count(!iszero, col) == 1 && any(col .== 1.0)
            row_index = findfirst(x -> x == 1.0, col)
            variable_values[j] = tableau[row_index, end]
        end
    end

    Z_opt = tableau[end, end]
    return tableau, Z_opt, variable_values, iter
end

"""
Muestra el tableau en formato legible.
"""
function print_tableau(tableau::Matrix{Float64})
    println("\n--- Tableau Simplex ---")
    for i in 1:size(tableau, 1)
        for j in 1:size(tableau, 2)
            @printf("%9.2f ", tableau[i, j])
        end
        println()
    end
end


# --- 5. Menú Principal ---

"""
Bucle del menú principal.
"""
function main_menu()
    # Inicializa el estado del problema
    problem = SimplexProblem()

    while true
        clear_screen()
        display_problem_summary(problem)
        
        println("\n--- MENÚ PRINCIPAL SIMPLEX ---")
        println("Seleccione la sección que desea gestionar:")
        println("1. Número de variables de decisión")
        println("2. Función objetivo")
        println("3. Restricciones")
        println("--------------------------------")
        println("4. Resolver")
        println("5. Salir")
        print("Seleccione una opción: ")

        choice = readline()

        if choice == "1"
            handle_variables(problem)
        elseif choice == "2"
            handle_objective(problem)
        elseif choice == "3"
            handle_constraints(problem)
        elseif choice == "4"
            try
                tableau = build_simplex_table(problem)
                println("\nTabla inicial del método Simplex:")
                print_tableau(tableau)

                tableau_final, z_opt, variable_values, iterations = simplex_solve(tableau)

                println("\nTabla final del método Simplex:")
                print_tableau(tableau_final)

                println("\n====================== RESULTADOS ======================")
                @printf("Número de iteraciones: %d\n", iterations)
                for (i, val) in enumerate(variable_values)
                    @printf("x%-2d = %8.4f\n", i, val)
                end
                println("-------------------------------------------------------")
                println("Valor óptimo de Z = $(round(z_opt, digits=4))")
                println("=======================================================")
            catch e
                println("\nError al resolver: ", e)
            end
            print("\nPresione Enter para continuar...")
            readline()
        elseif choice == "5"
            println("Saliendo del programa. ¡Adiós!")
            break
        else
            println("Opción no válida. Intente de nuevo.")
            print("Presione Enter para continuar...")
            readline()
        end
    end
end

# --- 6. Punto de Entrada ---
main_menu()
