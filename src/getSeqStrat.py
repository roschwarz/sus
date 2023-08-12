import bs4
import requests
import sys
import re
from bs4 import BeautifulSoup
from requests.exceptions import InvalidURL
import argparse

parser = argparse.ArgumentParser()

parser.add_argument('-id', '--id')

def buildURL(sra_number: str) -> str:

    url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=sra&id={sra_number}"
    return(url)


def getXML(sra_number) -> bs4.BeautifulSoup:
    
    response = requests.get(buildURL(sra_number), 'xml')

    try:
        response.raise_for_status()
    except requests.HTTPError as exception:
        return None

    return BeautifulSoup(response.text, 'lxml')

args=parser.parse_args()

xml = getXML(args.id)

if xml is None:
    print('Invalid Sra id')
    sys.exit()

for element in xml.find_all("library_layout"):
    if re.search('single', str(element)):
        print('single')
    elif re.search('paired', str(element)):
        print('paired')
    else:
        print(element)
