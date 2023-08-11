import bs4
import requests
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
        print(f'Mooooep something went wrong. HAHA!')
        raise InvalidURL("Don't know what is happening, see you")

    return BeautifulSoup(response.text, 'lxml')

args=parser.parse_args()

for element in getXML(args.id).find_all("library_layout"):
    if re.search('single', str(element)):
        print('single')
    elif re.search('paired', str(element)):
        print('paired')
    else:
        print(element)
