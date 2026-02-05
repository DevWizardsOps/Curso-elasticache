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
    Description: VPC onde os recursos serao criados
  
  SubnetId:
    Type: AWS::EC2::Subnet::Id
    Description: Subnet publica para instancias EC2
  
  AllowedCIDR:
    Type: String
    Default: 0.0.0.0/0
    Description: CIDR permitido para acesso SSH
  
  KeyPairName:
    Type: AWS::EC2::KeyPair::KeyName
    Description: Nome da chave SSH para acesso as instancias
  
  ConsolePasswordSecret:
    Type: String
    Description: Nome do secret no Secrets Manager contendo a senha do console

Mappings:
  RegionMap:
    us-east-1:
      AMI: ami-0c02fb55956c7d316
    us-east-2:
      AMI: ami-0807bd3aff0ae7273
    us-west-1:
      AMI: ami-0d9858aa3c6322f73
    us-west-2:
      AMI: ami-008fe2fc65df48dac
    eu-west-1:
      AMI: ami-01dd271720c1ba44f
    eu-central-1:
      AMI: ami-0f454ec961da9a046
    sa-east-1:
      AMI: ami-0c820c196a818d66a

Resources:
  # IAM Group para alunos
  CursoElastiCacheStudentsGroup:
    Type: AWS::IAM::Group
    Properties:
      GroupName: curso-elasticache-students
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess
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

  # Security Group para instancias EC2 dos alunos
  AlunosSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: curso-elasticache-alunos-sg
      GroupDescription: Security group para instancias EC2 dos alunos
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

  # Bucket S3 para laboratorios
  LabsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'curso-elasticache-labs-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
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
    ALUNO_ID_UPPER=$(echo "${ALUNO_ID}" | sed 's/./\U&/')
    
    cat << EOF
  # Usuario IAM para ${ALUNO_ID}
  ${ALUNO_ID_UPPER}User:
    Type: AWS::IAM::User
    Properties:
      UserName: curso-elasticache-${ALUNO_ID}
      Groups:
        - !Ref CursoElastiCacheStudentsGroup
      LoginProfile:
        Password: !Sub '{{resolve:secretsmanager:\${ConsolePasswordSecret}:SecretString:password}}'
        PasswordResetRequired: false
      Tags:
        - Key: Aluno
          Value: ${ALUNO_ID}
        - Key: Curso
          Value: ElastiCache

  # Access Keys para ${ALUNO_ID}
  ${ALUNO_ID_UPPER}AccessKey:
    Type: AWS::IAM::AccessKey
    Properties:
      UserName: !Ref ${ALUNO_ID_UPPER}User

  # Instancia EC2 para ${ALUNO_ID}
  ${ALUNO_ID_UPPER}Instance:
    Type: AWS::EC2::Instance
    DependsOn: 
      - LabsBucket
      - ${ALUNO_ID_UPPER}InstanceProfile
    Properties:
      ImageId: !FindInMap [RegionMap, !Ref 'AWS::Region', AMI]
      InstanceType: t3.micro
      KeyName: !Ref KeyPairName
      SubnetId: !Ref SubnetId
      SecurityGroupIds:
        - !Ref AlunosSecurityGroup
      IamInstanceProfile: !Ref ${ALUNO_ID_UPPER}InstanceProfile
      UserData:
        Fn::Base64: !Sub 
          - |
            #!/bin/bash
            # Aguardar IAM instance profile estar disponível (máximo 30s)
            for i in {1..30}; do
              if curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ > /dev/null 2>&1; then
                break
              fi
              sleep 1
            done
            
            # Baixar e executar script de setup do S3
            aws s3 cp s3://\${BucketName}/scripts/setup-aluno.sh /tmp/setup-aluno.sh --region \${AWS::Region}
            chmod +x /tmp/setup-aluno.sh
            /tmp/setup-aluno.sh "${ALUNO_ID}" "\${AWS::Region}" "\${AccessKey}" "\${SecretKey}" >> /var/log/setup-aluno.log 2>&1
          - AccessKey: !Ref ${ALUNO_ID_UPPER}AccessKey
            SecretKey: !GetAtt ${ALUNO_ID_UPPER}AccessKey.SecretAccessKey
            BucketName: !Ref LabsBucket
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
        Timeout: PT15M

  # IAM Role para instancia EC2 do ${ALUNO_ID}
  ${ALUNO_ID_UPPER}InstanceRole:
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
                  - !Sub 'arn:aws:s3:::curso-elasticache-labs-\${AWS::AccountId}'
                  - !Sub 'arn:aws:s3:::curso-elasticache-labs-\${AWS::AccountId}/*'
      Tags:
        - Key: Aluno
          Value: ${ALUNO_ID}
        - Key: Curso
          Value: ElastiCache

  # Instance Profile para ${ALUNO_ID}
  ${ALUNO_ID_UPPER}InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      InstanceProfileName: curso-elasticache-${ALUNO_ID}-profile
      Roles:
        - !Ref ${ALUNO_ID_UPPER}InstanceRole

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
    Description: Nome do bucket S3 para laboratorios
    Value: !Ref LabsBucket
    Export:
      Name: !Sub '${AWS::StackName}-Labs-Bucket'

  ConsolePasswordSecret:
    Description: Nome do secret contendo a senha do console
    Value: !Ref ConsolePasswordSecret
    Export:
      Name: !Sub '${AWS::StackName}-ConsolePassword-Secret'

  SecretsManagerURL:
    Description: Link para o Secrets Manager
    Value: !Sub 'https://console.aws.amazon.com/secretsmanager/home?region=${AWS::Region}#!/secret?name=${ConsolePasswordSecret}'

EOF

# Gerar outputs para cada aluno
for i in $(seq 1 "$NUM_ALUNOS"); do
    ALUNO_NUM=$(pad_number "$i")
    ALUNO_ID="${PREFIXO_ALUNO}${ALUNO_NUM}"
    ALUNO_ID_UPPER=$(echo "${ALUNO_ID}" | sed 's/./\U&/')
    
    cat << EOF
  ${ALUNO_ID_UPPER}PublicIP:
    Description: IP publico da instancia do ${ALUNO_ID}
    Value: !GetAtt ${ALUNO_ID_UPPER}Instance.PublicIp
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID_UPPER}-Public-IP'

  ${ALUNO_ID_UPPER}PrivateIP:
    Description: IP privado da instancia do ${ALUNO_ID}
    Value: !GetAtt ${ALUNO_ID_UPPER}Instance.PrivateIp
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID_UPPER}-Private-IP'

  ${ALUNO_ID_UPPER}InstanceId:
    Description: Instance ID do ${ALUNO_ID}
    Value: !Ref ${ALUNO_ID_UPPER}Instance
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID_UPPER}-Instance-ID'

  ${ALUNO_ID_UPPER}AccessKeyId:
    Description: Access Key ID do ${ALUNO_ID}
    Value: !Ref ${ALUNO_ID_UPPER}AccessKey
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID_UPPER}-Access-Key-ID'

  ${ALUNO_ID_UPPER}SecretAccessKey:
    Description: Secret Access Key do ${ALUNO_ID}
    Value: !GetAtt ${ALUNO_ID_UPPER}AccessKey.SecretAccessKey
    Export:
      Name: !Sub '\${AWS::StackName}-${ALUNO_ID_UPPER}-Secret-Access-Key'

EOF
done