#!/bin/bash

echo "Iniciando configuração do ambiente"

echo "Atualizando pacotes"

	sudo apt update && sudo apt upgrade -y

if [ $? = 0 ]; then

    echo "Pacotes atualizados com sucesso!"

else

    echo "Erro ao atualizar os pacotes"
    exit 1

fi

echo "Deseja criar contêiners? [s/n]"

	read input

	if [ "$input" = "s" ]; then 
		
	 	docker --version #verifica versao atual do docker

        if [ $? = 0 ]; 
        then 
        	echo "Você já possui o Docker instalado!" 
	    else 
			echo "Instalando o Docker"
			sudo apt install docker.io -y 
			sudo systemctl enable docker 
			sudo systemctl start docker
			echo "Docker instalado com sucesso!"	

			if [ $? -ne 0 ]; then
            echo "Erro ao instalar ou iniciar o Docker"
            exit 1
        	fi
		fi

		mkdir -p "$HOME/low-latency"
    	cd "$HOME/low-latency" 

		echo "Baixando os arquivos do banco de dados"
		if [ -d "Banco-de-dados" ]; then

        echo "O repositorio do banco ja existe!"

   		else

       		git clone "https://github.com/LowLatencyOrg/Banco-de-dados.git"

    	fi

		cd Banco-de-dados
		mkdir -p arquivos_sql
		cp script-low-latency.sql arquivos_sql/001-script-low-latency.sql

		echo "Criando dockerfile do banco"
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM mysql:8
COPY ./arquivos_sql/ /docker-entrypoint-initdb.d/
DOCKERFILE_EOF
		

		echo "Criando imagem banco de dados"
		sudo docker build -t low-latency-banco .

		if [ $? = 0 ]; then

       		echo "Imagem do banco criada com sucesso!"

    	else

        	echo "Erro ao criar a imagem do banco"
        	exit 1
    	fi

		echo "Digite a senha do usuario root do MySQL:"
        read -s senha
        echo

        sudo docker run -d \
            --name ctr-banco-de-dados \
            -e MYSQL_ROOT_PASSWORD="$senha" \
            -p 3306:3306 \
            low-latency-banco

        if [ $? -eq 0 ]; then
            echo "Container do banco criado!"
        else
            echo "Erro ao criar o container do banco"
        fi


		echo "Verificando a existência do Node"
		if command -v node >/dev/null 2>&1; then
			node -v
			echo "Node.js ja esta instalado!"
		else
			echo "Node.js nao esta instalado na EC2."
			echo "A aplicacao usara a imagem oficial do Node no Docker."
		fi

		cd "$HOME/low-latency"

		echo "Baixando os arquivos da API"
		if [ -d "Site-Grupo10" ]; then

        echo "O repositorio da API ja existe!"

   		else

       		git clone "https://github.com/LowLatencyOrg/Site-Grupo10.git"

    	fi
		
		cd Site-Grupo10
		echo "Criando dockerfile do site"
cat << 'DOCKERFILE_EOF' > Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3333
CMD ["npm", "start"]
DOCKERFILE_EOF

		echo "Dockerfile criado com sucesso!"

		echo "Deseja iniciar a API? [s/n]"
		read input
		if [ "$input" == "s" ]; then
		
			echo "Construindo a imagem Docker"
			sudo docker build -t low-latency-imagem .

			echo "Iniciando o container"
			sudo docker run -d --name low-latency-api -p 3333:3333 low-latency-imagem

		if [ $? -eq 0 ]; then
                echo "Container da aplicacao iniciado!"
                echo "Teste usando http://IP-PUBLICO-DA-EC2:3333"
            else
                echo "Erro ao iniciar o container da aplicacao"
            fi

        else
            echo "Inicializacao da API cancelada"
        fi

    

else

    echo "Executando o caminho sem containers"

    echo "Instalando o MySQL"
    sudo apt install mysql-server -y

    echo "Instalando o Node.js"
    sudo apt install nodejs npm -y

    mkdir -p "$HOME/low-latency"
    cd "$HOME/low-latency" || exit 1

    if [ -d "Banco-de-dados" ]; then
        echo "Repositorio do banco ja existe!"
    else
        git clone https://github.com/LowLatencyOrg/Banco-de-dados.git
    fi

    cd Banco-de-dados || exit 1

    echo "Criando o banco a partir do SQL"
    sudo mysql < script-low-latency.sql

fi