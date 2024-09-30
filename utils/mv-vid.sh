for file in *.mp4; do
  dir="${file%.*}"
  mkdir -p "$dir"
  mv "$file" "$dir/"
done
