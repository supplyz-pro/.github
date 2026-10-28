from pathlib import Path
import yaml, shutil, time
root=Path('/home/sami/langfuse-observe')
p=root/'docker-compose.override.yml'
shutil.copy2(p,p.with_suffix('.yml.sup313-backup-'+str(int(time.time()))))
d=yaml.safe_load(p.read_text()) or {}
service=d.setdefault('services',{}).setdefault('clickhouse',{})
service['logging']={'driver':'local','options':{'max-size':'10m','max-file':'3'}}
config=root/'clickhouse-disk-logging.xml'
config.write_text('<clickhouse><logger><level>warning</level><console>true</console><log remove="remove"/><errorlog remove="remove"/><size>10M</size><count>3</count></logger></clickhouse>\n')
config.chmod(0o644)
volumes=service.setdefault('volumes',[])
mount='./clickhouse-disk-logging.xml:/etc/clickhouse-server/config.d/disk-logging.xml:ro'
if mount not in volumes: volumes.append(mount)
p.write_text(yaml.safe_dump(d,sort_keys=False))
print('ClickHouse logging override updated; existing data mounts preserved')
