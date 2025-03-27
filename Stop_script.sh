  GNU nano 7.2               Stop_script.sh                        
#!/bin/bash

echo " ^=^t^m Zoeken naar VM's met ID > 200..."

# Haal alle VMID's op
VM_IDS=$(qm list | awk 'NR>1 {print $1}' | grep -E '^[0-9]+$')

for VMID in $VM_IDS; do
  if [ "$VMID" -gt 99 & !200 ]; then
    VM_NAME=$(qm config $VMID | grep '^name:' | cut -d ' ' -f2-)
    echo " ^z   ^o  VM $VMID ($VM_NAME) wordt gestopt en verwijder>

    # Stop VM (forceer als nodig)
    qm stop $VMID > /dev/null 2>&1

    # Destroy VM
    qm destroy $VMID --purge > /dev/null 2>&1

    echo " ^=^w^q  ^o  Verwijderd: $VMID ($VM_NAME)"
  fi
done

echo " ^|^e Alles met ID > 200 is opgeruimd."


