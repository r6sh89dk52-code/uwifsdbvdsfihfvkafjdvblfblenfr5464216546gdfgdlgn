"""Host process selection restricted to one owned synthetic Simulator."""
def find_owned_app(listing,sim):
    fragment='/CoreSimulator/Devices/'+sim+'/data/Containers/Bundle/Application/'
    for line in listing.splitlines():
        fields=line.strip().split(None,1)
        if len(fields)!=2 or not fields[0].isdigit():continue
        executable=fields[1].split()[0]
        if fragment in executable and executable.endswith('/DANPERNative.app/DANPERNative'):
            return fields[0]
    return None
