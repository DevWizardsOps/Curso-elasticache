#!/bin/bash

# Gerador de template CloudFormation dinâmico para curso ElastiCache
# Baseado no padrão do curso DocumentDB

NUM_ALUNOS=${1:-2}
PREFIXO_ALUNO=${2:-aluno}

if [ "$NUM_ALUNOS" -lt 1 ] || [ "$NUM_ALUNOS" -gt 20 ]; then
    echo "❌ Erro: Número de alunos deve estar entre 1 e 20" >&2
    exit 1
fi

# Função para gerar número com zero à esquerda
pad_number() {
    printf "%02d" "$1"
}

cat << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Curso AWS ElastiCache - Ambiente automatizado para alunos'

Parameters:
  PrefixoAluno:
    Type: String
    Default: aluno
    Description: Prefixo para nomes dos alunos
  
  VpcId:
    Type: AWS::EC2::VPC::Id
    Description: VPC onde os recursos serão criados
  
  SubnetId:
    Type: AWS::EC2::Subnet::Id
    Description: Subnet pública para instâncias EC2
  
  AllowedCIDR:
    Type: String
    Default: 0.0.0.0/0
    Description: CIDR permitido para acesso SSH
  
  KeyPairName:
    Type: AWS::EC2::KeyPair::KeyName
    Description: Nome da chave SSH para acesso às instâncias

Resources:
  # IAM Group para alunos
  CursoElastiCacheStudentsGroup:
    Type: AWS::IAM::Group
    Properties:
      GroupName: curso-elasticache-students
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/ElastiCacheFullAccess
        - arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess
        - arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess
      Policies:
        - PolicyName: ElastiCacheLabPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ec2:DescribeVpcs
                  - ec2:DescribeSubnets
                  - ec2:DescribeSecurityGroups
                  - ec2:DescribeNetworkInterfaces
                  - ec2:CreateSecurityGroup
                  - ec2:AuthorizeSecurityGroupIngress
                  - ec2:AuthorizeSecurityGroupEgress
                  - ec2:RevokeSecurityGroupIngress
                  - ec2:RevokeSecurityGroupEgress
                  - ec2:DeleteSecurityGroup
                  - ec2:CreateTags
                Resource: '*'
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:ListBucket
                Resource:
                  - !Sub 'arn:aws:s3:::curso-elasticache-labs-${AWS::AccountId}'
                  - !Sub 'arn:aws:s3:::curso-elasticache-labs-${AWS::AccountId}/*'
              - Effect: Allow
                Action:
                  - sts:GetCallerIdentity
                Resource: '*'

  # Security Group para instâncias EC2 dos alunos
  AlunosSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: curso-elasticache-alunos-sg
      GroupDescription: Security group para instâncias EC2 dos alunos
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref AllowedCIDR
          Description: SSH access
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: All outbound traffic
      Tags:
        - Key: Name
          Value: curso-elasticache-alunos-sg
        - Key: Curso
          Value: ElastiCache

  # Security Group para clusters ElastiCache
  ElastiCacheSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: curso-elasticache-clusters-sg
      GroupDescription: Security group para clusters ElastiCache
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 6379
          ToPort: 6379
          SourceSecurityGroupId: !Ref AlunosSecurityGroup
          Description: Redis access from student instances
      Tags:
        - Key: Name
          Value: curso-elasticache-clusters-sg
        - Key: Curso
          Value: ElastiCache

  # Bucket S3 para laboratórios
  LabsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'curso-elasticache-labs-${AWS::AccountId}'
      PublicReadPolicy: false
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      Tags:
        - Key: Curso
          Value: ElastiCache

EOF

# Gerar recursos para cada aluno
for i in $(seq 1 "$NUM_ALUNOS"); do
    ALUNO_NUM=$(pad_number "$i")
    ALUNO_ID="${PREFIXO_ALUNO}${ALUNO_NUM}"
    
    cat << EOF
  # Usuário IAM para ${ALUNO_ID}
  ${ALUNO_ID^}User:
    Type: AWS::IAM::User
    Properties:
      UserName: curso-elasticache-${ALUNO_ID}
      Groups:
        - !Ref CursoElastiCacheStudentsGroup
      LoginProfile:
        Password: Extractta@2026
        PasswordResetRequired: true
      Tags:
        - Key: Aluno
          Value: ${ALUNO_ID}
        - Key: Curso
          Value: ElastiCache

  # Access Keys para ${ALUNO_ID}
  ${ALUNO_ID^}AccessKey:
    Type: AWS::IAM::AccessKey
    Properties:
      UserName: !Ref ${ALUNO_ID^}User

  # Instância EC2 para ${ALUNO_ID}
  ${ALUNO_ID^}Instance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: ami-0c02fb55956c7d316  # Amazon Linux 2 (us-east-1)
      InstanceType: t3.micro
      KeyName: !Ref KeyPairName
      SubnetId: !Ref SubnetId
      SecurityGroupIds:
        - !Ref AlunosSecurityGroup
      IamInstanceProfile: !Ref ${ALUNO_ID^}InstanceProfile
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          yum update -y
          
          # Instalar ferramentas básicas
          yum install -y git htop tree wget curl unzip
          
          # Configurar AWS CLI com as credenciais do aluno
          mkdir -p /home/ec2-user/.aws
          cat > /home/ec2-user/.aws/credentials << 'EOL'
          [default]
          aws_access_key_id = \${${ALUNO_ID^}AccessKey}
          aws_secret_access_key = \${${ALUNO_ID^}AccessKey.SecretAccessKey}
          region = \${AWS::Region}
          EOL
          
          cat > /home/ec2-user/.aws/config << 'EOL'
          [default]
          region = \${AWS::Region}
          output = json
          EOL
          
          chown -R ec2-user:ec2-user /home/ec2-user/.aws
          chmod 600 /home/ec2-user/.aws/credentials
          chmod 600 /home/ec2-user/.aws/config
          
          # Instalar Redis CLI
          amazon-linux-extras install -y redis6
          
          # Instalar MongoDB tools (para comparação nos labs)
          wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-amazon2-x86_64-100.6.1.rpm
          rpm -ivh mongodb-database-tools-amazon2-x86_64-100.6.1.rpm
          rm mongodb-database-tools-amazon2-x86_64-100.6.1.rpm
          
          # Instalar Node.js (para RedisInsight e scripts)
          curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
          yum install -y nodejs
          
          # Instalar RedisInsight
          cd /opt
          wget https://download.redislabs.com/redisinsight/latest/redisinsight-linux64-latest.tar.gz
          tar -xzf redisinsight-linux64-latest.tar.gz
          rm redisinsight-linux64-latest.tar.gz
          chown -R ec2-user:ec2-user redisinsight-linux64-*
          
          # Criar link simbólico para RedisInsight
          ln -s /opt/redisinsight-linux64-*/redisinsight /usr/local/bin/redisinsight
          
          # Criar diretório de trabalho
          mkdir -p /home/ec2-user/labs
          cd /home/ec2-user/labs
          
          # Baixar materiais do curso (se disponível)
          # aws s3 sync s3://curso-elasticache-labs-\${AWS::AccountId}/labs/ . || true
          
          # Criar script de conveniência
          cat > /home/ec2-user/labs/info.sh << 'EOL'
          #!/bin/bash
          echo "=== Informações do Ambiente ==="
          echo "Aluno: ${ALUNO_ID}"
          echo "Região: \${AWS::Region}"
          echo "Account ID: \${AWS::AccountId}"
          echo "IP Público: \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
          echo "IP Privado: \$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
          echo ""
          echo "=== Ferramentas Instaladas ==="
          echo "AWS CLI: \$(aws --version)"
          echo "Redis CLI: \$(redis-cli --version)"
          echo "Node.js: \$(node --version)"
          echo "RedisInsight: \$(ls -la /usr/local/bin/redisinsight)"
          echo ""
          echo "=== Conectividade AWS ==="
          aws sts get-caller-identity
          EOL
          
          chmod +x /home/ec2-user/labs/info.sh
          
          # Criar alias úteis
          cat >> /home/ec2-user/.bashrc << 'EOL'
          alias labs='cd ~/labs'
          alias info='~/labs/info.sh'
          alias ll='ls -la'
          EOL
          
          chown -R ec2-user:ec2-user /home/ec2-user/labs
          
          # Sinalizar conclusão
          /opt/aws/bin/cfn-signal -e \$? --stack \${AWS::StackName} --resource ${ALUNO_ID^}Instance --region \${AWS::Region}
      Tags:
        - Key: Name
          Value: curso-elasticache-${ALUNO_ID}
        - Key: Aluno
          Value: ${ALUNO_ID}
        - Key: Curso
          Value: ElastiCache
    CreationPolicy:
      ResourceSignal:
        Count: 1
        Timeout: PT10M

  # IAM Role para instância EC2 do ${ALUNO_ID}
  ${ALUNO_ID^}InstanceRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: curso-elasticache-${ALUNO_ID}-role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
      Policies:
        - PolicyName: ElastiCacheLabInstancePolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:ListBucket
                Resource:
                  - !Sub 'arn:aws:s3:::curso-elasticache-labs-${AWS::AccountId}'
                  - !Sub 'arn:aws:s3:::curso-elasticache-labs-${AWS::AccountId}/*'
      Tags:
        - Key: Aluno
          Value: ${ALUNO_ID}
        - Key: Curso
          Value: ElastiCache

  # Instance Profile para ${ALUNO_ID}
  ${ALUNO_ID^}InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      InstanceProfileName: curso-elasticache-${ALUNO_ID}-profile
      Roles:
        - !Ref ${ALUNO_ID^}InstanceRole

EOF
done

# Gerar outputs
cat << 'EOF'

Outputs:
  StackName:
    Description: Nome da stack CloudFormation
    Value: !Ref AWS::StackName
    Export:
      Name: !Sub '${AWS::StackName}-StackName'

  VPCId:
    Description: VPC ID utilizada
    Value: !Ref VpcId
    Export:
      Name: !Sub '${AWS::StackName}-VPC-ID'

  AlunosSecurityGroupId:
    Description: Security Group ID para alunos
    Value: !Ref AlunosSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-Alunos-SG-ID'

  ElastiCacheSecurityGroupId:
    Description: Security Group ID para ElastiCache
    Value: !Ref ElastiCacheSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-ElastiCache-SG-ID'

  LabsBucketName:
    Description: Nome do bucket S3 para laboratórios
    Value: !Ref LabsBucket
    Export:
      Name: !Sub '${AWS::StackName}-Labs-Bucket'

EOF

# Gerar outputs para cada aluno
for i in $(seq 1 "$NUM_ALUNOS"); do
    ALUNO_NUM=$(pad_number "$i")
    ALUNO_ID="${PREFIXO_ALUNO}${ALUNO_NUM}"
    
    cat << EOF
  ${ALUNO_ID^}PublicIP:
    Description: IP público da instância do ${ALUNO_ID}
    Value: !GetAtt ${ALUNO_ID^}Instance.PublicIp
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID^}-Public-IP'

  ${ALUNO_ID^}PrivateIP:
    Description: IP privado da instância do ${ALUNO_ID}
    Value: !GetAtt ${ALUNO_ID^}Instance.PrivateIp
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID^}-Private-IP'

  ${ALUNO_ID^}InstanceId:
    Description: Instance ID do ${ALUNO_ID}
    Value: !Ref ${ALUNO_ID^}Instance
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID^}-Instance-ID'

  ${ALUNO_ID^}AccessKeyId:
    Description: Access Key ID do ${ALUNO_ID}
    Value: !Ref ${ALUNO_ID^}AccessKey
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID^}-Access-Key-ID'

  ${ALUNO_ID^}SecretAccessKey:
    Description: Secret Access Key do ${ALUNO_ID}
    Value: !GetAtt ${ALUNO_ID^}AccessKey.SecretAccessKey
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID^}-Secret-Access-Key'

EOF
done