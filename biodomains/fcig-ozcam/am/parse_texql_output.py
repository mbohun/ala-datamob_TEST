#!/usr/bin/env python

"""
on stdin get output of a textql query result looking like this:
((1005442),['jpeg'|'jpeg'|'jpeg'|'jpeg'],'1005/442/TODERAS 038.jpg',['Della Ross'],'Della Ross',['TODERAS 038.jpg'|'TODERAS 038.thumb.jpg'|'TODERAS 038.200x200.jpg'|'TODERAS 038.520x520.jpg'],[164087|12094|24625|165652])
fileds are irn, DocMimeFormat_tab, Multimedia, MulCreator_tab, DetPublisher, DocIdentifier_tab, DocFileSize_tab
what a mess.
for each image file print a tab-delimited row with the unpacked values fo these fields
"""

import sys
from os.path import exists

MAXSIZE = 500000
MINSIZE = 50000
MEDIADIR = '/data/amweb/multimedia'

for line in sys.stdin:
	line = line.strip('\n')
	assert line.startswith('((') and line.endswith(')')
	line = line [2:-1]
	assert line.endswith(']')
	#print line
	(irn , rest) = line.split('),[',1)
	#print irn
	#print rest
	DocMimeFormat_tab, rest = rest.split("],'",1)
	DocMimeFormat_tab = DocMimeFormat_tab[1:-1].split("'|'")
	#print DocMimeFormat_tab
	#print rest
	Multimedia,rest = rest.split("',['",1)
	subdir = '/'.join(Multimedia.split('/')[:-1])
	#print Multimedia
	#print rest
	MulCreator_tab,rest = rest.split("'],'",1)
	#print MulCreator_tab
	#print rest
	DetPublisher,rest = rest.split("',[",1)
	#print DetPublisher
	#print rest
	DocIdentifier_tab,rest = rest.split("],",1)
	DocIdentifier_tab = DocIdentifier_tab.strip("'").split("'|'")
	#print DocIdentifier_tab
	#print rest
	DocFileSize_tab = rest.strip('[').strip(']').split('|')
	DocFileSize_tab = [ int(i) for i in DocFileSize_tab ]
	#print DocFileSize_tab

	assert len(DocMimeFormat_tab) == len(DocIdentifier_tab)
	assert len(DocMimeFormat_tab) == len(DocFileSize_tab)
	files = zip(DocFileSize_tab,DocMimeFormat_tab,DocIdentifier_tab)
	files.sort()
	files.reverse() #now sorted by filesize descending order
	printed = False
	for DocFileSize, DocMimeFormat, DocIdentifier in files:
		if not printed:
			DocFileSize = str(DocFileSize)
			if DocMimeFormat.lower() in ['jpeg','png'] and int(DocFileSize) <= MAXSIZE and int(DocFileSize) >= MINSIZE:
				path = '/'.join( [ MEDIADIR , subdir, DocIdentifier ] )
				rel_path = '/'.join( [ 'multimedia', subdir, DocIdentifier ] )
				if exists(path):
					print '\t'.join([irn, MulCreator_tab, DetPublisher, Multimedia, DocIdentifier, DocMimeFormat, DocFileSize, rel_path])
					printed = True
				else:
					path = path.replace('JPG', 'jpg')
					DocIdentifier = DocIdentifier.replace('JPG', 'jpg')
					rel_path = rel_path.replace('JPG', 'jpg')
					if exists(path):
						print '\t'.join([irn, MulCreator_tab, DetPublisher, Multimedia, DocIdentifier, DocMimeFormat, DocFileSize, rel_path])
						printed = True
					else:
						print path, 'not found'
