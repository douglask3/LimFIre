## Copy reqired hooks
hooksPath="gitinfoHooks/"
hooksDir="../.git/hooks/"
export TEXMFHOME=texmf


fnames=`ls $hooksPath`
cp `find $hooksPath | tail -n +2` $hooksDir

for i in `ls $hooksPath`
do
    f=$hooksDir$i
    echo $f
    chmod +x $f
done

rm *.bbl
rm *.aux
rm *.blg
rm *.log
rm *.dvi
 
pdflatex notes.tex
pdflatex Model_description.tex
bibtex Model_description
pdflatex Model_description.tex
pdflatex Model_description.tex

rm *.bbl
rm *.aux
rm *.blg
rm *.log
rm *.dvi

xpdf Model_description.pdf
